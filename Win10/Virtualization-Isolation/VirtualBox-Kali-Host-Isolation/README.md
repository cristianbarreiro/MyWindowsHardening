# Windows 10 — VirtualBox / Kali Host Isolation

<sup>Perfil de aislamiento entre una VM Kali Linux y un host Windows 10 · VirtualBox NAT</sup>

**Estado:** configuración aplicada y validada en un único equipo; documentación técnica de la implementación.  
**Host de referencia:** Windows 10 Home Single Language x64, 22H2, build 19045.  
**Hipervisor de referencia:** Oracle VirtualBox 7.2.22r175245.  
**VM principal:** `kali-linux-2026.3-virtualbox-amd64`.  
**VM secundaria observada:** `PrivGuard-W11-Manual`.

> Este documento registra un estado concreto y sus decisiones. No es un instalador genérico. Los scripts de aplicación y los rollback de la sesión se conservaron como copias locales; no se publican aquí como automatización reutilizable porque no forman un único instalador revisado.

## 1. Objetivo

Reducir los caminos por los que un proceso o servicio dentro de Kali pueda iniciar conexiones hacia el host Windows, acceder a servicios compartidos del host o aprovechar integraciones innecesarias de VirtualBox.

El diseño mantiene conectividad saliente de Kali mediante NAT para permitir actualizaciones, herramientas y laboratorios, pero reduce las interfaces y servicios innecesarios del host.

**Resultado buscado:** que una actividad web o de laboratorio ejecutada dentro de Kali se origine en el navegador/sistema invitado y no tenga acceso normal a los archivos, procesos ni sesiones de Windows. Esto no implica que el hipervisor o la existencia de una VM sean indetectables, ni que NAT sea una barrera completa contra una VM comprometida.

## 2. Entorno validado

| Elemento | Estado de referencia |
|---|---|
| Host | Windows 10 Home Single Language x64, 22H2, build 19045 |
| VirtualBox | 7.2.22r175245 |
| VM Kali | Kali Linux 2026.3, VirtualBox |
| Red de Kali | Adaptador 1 NAT; adaptadores 2–8 sin conexión |
| Red de la VM secundaria | Adaptador 1 NAT; adaptadores 2–8 sin conexión |
| Adaptadores Host-Only del host | Ethernet2 y Ethernet3 deshabilitados, no eliminados |
| Filtro Bridged de VirtualBox | `oracle_VBoxNetLwf` deshabilitado en los adaptadores del host |
| Integración VM↔Host | Carpetas compartidas, portapapeles compartido y drag-and-drop deshabilitados; 3D desactivado |
| NAT localhost | `LocalhostReachable=0` en la configuración NAT de las VM |

Los nombres y versiones anteriores corresponden al equipo de validación. En otra instalación, verificar cada valor con VirtualBox antes de considerar el perfil equivalente.

## 3. Controles aplicados

### 3.1 Firewall de Windows

- Perfiles Domain, Private y Public habilitados.
- Política predeterminada de entrada: **Block**.
- Política predeterminada de salida: **Allow**.
- Registro de conexiones bloqueadas habilitado.
- Se restringieron reglas entrantes que no necesitaban exposición en redes públicas.
- Se deshabilitaron excepciones entrantes asociadas a funciones no utilizadas: descubrimiento, UPnP, mDNS, proximidad, Wireless Display, PlayTo/DIAL, Remote Assistance y reglas entrantes amplias de determinadas aplicaciones.
- Se deshabilitaron excepciones entrantes de Spotify, Slack, Correo y Calendario UWP, Xbox Game Bar, Microsoft Store y Antigravity IDE. El detalle de las 15 reglas explícitas verificadas figura en [VALIDATION.md](./VALIDATION.md).
- Se conservaron reglas de Core Networking, HNS/ICS/DNS, FrameServer, Windows Backup Client y paquetes UWP que seguían presentes. No se deshabilitaron indiscriminadamente las reglas restantes.
- Se agregaron reglas de bloqueo de entrada desde la subred NAT de VirtualBox `10.0.2.0/24`, SMB TCP y NetBIOS UDP.

La política Outbound permanece en Allow. Por lo tanto, las reglas entrantes y la política del host no deben interpretarse como un bloqueo general de las conexiones que Kali inicia hacia Internet o hacia otros equipos de la LAN.

### 3.2 SMB: host como cliente, no como servidor

El objetivo operativo es conservar Windows como cliente SMB y evitar que actúe como servidor de archivos por la red:

- `LanmanServer`: Stopped / Disabled.
- `LanmanWorkstation`: Running / Automatic.
- Binding `ms_server`: deshabilitado en las interfaces.
- Binding `ms_msclient`: conservado.
- SMB1 Server: deshabilitado.
- SMB2/3 Server: deshabilitado.
- SMB Client Signing: requerido.
- Inicios de sesión Guest SMB inseguros: deshabilitados.
- Bloqueo entrante de TCP 139/445 y UDP 137/138.

**Advertencia de interpretación:** durante la validación seguía apareciendo un listener `::445` asociado a PID 4 (System). Esto no demuestra por sí solo que se estén compartiendo recursos SMB. Se validaron también el estado de `LanmanServer`, los protocolos SMB Server y las reglas de entrada. No se deben deshabilitar drivers o componentes del kernel solo por observar PID 4 sin identificar antes su función.

### 3.3 VirtualBox y topología

- Kali y la VM secundaria usan exclusivamente NAT.
- NIC 2–8 están en `none`.
- Los adaptadores Host-Only Ethernet2/Ethernet3 se conservaron pero se deshabilitaron.
- El filtro NDIS de Bridged `oracle_VBoxNetLwf` está deshabilitado.
- No se habilitaron carpetas compartidas ni integración de portapapeles/arrastrar y soltar.
- La aceleración 3D quedó deshabilitada.
- `LocalhostReachable=0` impide el camino NAT especial desde el invitado hacia el loopback del host a través de `10.0.2.2`.

NAT no es un air gap. El invitado conserva conectividad saliente y puede alcanzar destinos de red a los que el host le permita enrutar tráfico. La regla de firewall que bloquea la subred NAT está dirigida a la entrada al host; no constituye una política universal de aislamiento de todos los equipos de la LAN.

### 3.4 Descubrimiento, servicios y funciones inalámbricas

Se detuvieron y deshabilitaron los siguientes servicios de descubrimiento que no se utilizan en el equipo:

- `FDResPub` — Function Discovery Resource Publication.
- `fdPHost` — Function Discovery Provider Host.
- `SSDPSRV` — SSDP Discovery.
- `upnphost` — UPnP Device Host.

También se deshabilitaron las reglas entrantes de los grupos de descubrimiento correspondientes y reglas para funciones no utilizadas, incluidas Wireless Display/WFD, Server DIAL, PlayTo/streaming, proximidad, mDNS, AllJoyn y Remote Assistance.

Se preservaron servicios necesarios para el uso normal del equipo y de la VM, entre ellos:

- `WlanSvc` — Wi-Fi.
- `Spooler` — impresión local.
- `VBoxSDS` — servicio de VirtualBox.
- `vmcompute`, HNS y componentes WSL.
- `SharedAccess` — quedó Manual; no se deshabilitó indiscriminadamente.

Las reglas de entrada amplias de Tenorshare 4DDiG se deshabilitaron; no se desinstaló el producto ni se alteraron sus conexiones salientes.

### 3.5 Delivery Optimization

- `DoSvc`: Running / Automatic.
- Modo configurado: `CdnOnly`.
- Se deshabilitaron dos reglas entrantes de firewall de Delivery Optimization para TCP/UDP 7680.
- No se detuvo el servicio ni se limpió su caché.
- En la medición inicial, los contadores de transferencia entre pares estaban en cero; ese dato es una observación puntual, no una garantía histórica de ausencia de tráfico P2P.

### 3.6 Microsoft Defender y Controlled Folder Access

Estado validado:

- Antivirus Microsoft Defender activo.
- Real-time protection, Behavior Monitor, IOAV y NIS activos.
- Tamper Protection activo.
- PUA Protection = 1 (Enabled).
- Controlled Folder Access (CFA) = 1 (Enabled).
- Network Protection = 2 (Audit Mode).

CFA se activó después de revisar eventos de auditoría. Los eventos 1124 iniciales se relacionaban con `git.exe`/Git fsmonitor escribiendo cookies de monitoreo en antiguas ubicaciones de repositorios. Se trasladaron los repositorios a D: y se detuvieron procesos antiguos; después de activar CFA no se observaron eventos 1123/1124/1127/1128 en el período de validación.

No se agregó `git.exe` a la lista global de aplicaciones permitidas ni se añadió `D:\Dev\GitHub` a las carpetas protegidas de CFA. Esa carpeta de desarrollo requiere escrituras de herramientas y debe evaluarse por separado antes de protegerla.

**Network Protection no se considera aplicado en modo Enforcement:** permanece en Audit Mode. La edición Home y la plataforma deben verificarse antes de atribuirle protección efectiva.

## 4. Resultado esperado al usar Kali para solicitudes web

Una solicitud HTTP/HTTPS generada por el navegador de Kali se origina en el entorno invitado. El sitio remoto normalmente recibe la huella del navegador y del sistema invitado, no una consulta a los procesos o archivos de Windows. No obstante:

- El hardware virtual puede revelar que el sistema corre en VirtualBox.
- La red NAT puede mostrar al invitado una puerta de enlace `10.0.2.2` y DNS `10.0.2.3`; esto identifica la topología NAT de VirtualBox, no demuestra por sí solo la identidad del host Windows.
- Sin VPN independiente dentro de Kali, el sitio puede ver la misma IP pública de salida que utiliza la conectividad del host.
- Si una VPN se ejecuta dentro de Kali y realmente transporta su tráfico, el sitio verá la IP de salida de esa VPN. Debe comprobarse desde el invitado, no inferirse por la presencia de una VPN en Windows.
- Una cuenta, cookie, método de pago o dato personal puede identificar al usuario con independencia del sistema operativo o de la IP.
- La operadora móvil, el proveedor VPN y el host observan distintos metadatos de transporte. La VPN cifra el túnel hasta el proveedor, pero no vuelve anónimo al usuario frente al servicio en el que inicia sesión.

La presencia de Proton VPN (incluido su Advanced Kill Switch) y Cloudflare WARP en el host se preservó. No se modificaron sus adaptadores, rutas o políticas. La ruta efectiva de Kali a través de ellos no se da por validada por su mera instalación; debe verificarse dentro de Kali.

## 5. Qué no garantiza

Este perfil no garantiza:

- invisibilidad de VirtualBox o de la virtualización;
- anonimato, separación de identidad o una IP pública exclusiva;
- bloqueo de conexiones salientes desde Kali hacia Internet o cualquier destino de la LAN;
- contención frente a una vulnerabilidad de escape del hipervisor;
- aislamiento frente a vulnerabilidades de VirtualBox, del kernel del host o del invitado;
- protección si se habilitan carpetas compartidas, portapapeles, USB passthrough u otras integraciones;
- protección de los datos del host ante un usuario que los copie manualmente al invitado;
- cifrado de los discos C: y D:;
- cobertura ESU ni actualización completa de Windows 10.

Para un air gap real hay que retirar la conectividad de la VM o diseñar una red interna sin salida; NAT no equivale a ninguna de esas dos opciones.

## 6. Archivos complementarios

- [SCOPE.md](./SCOPE.md): objetivos, controles, exclusiones y riesgos residuales.
- [VALIDATION.md](./VALIDATION.md): resultados de la validación final del 13/11/2026.
- [OPERATIONS.md](./OPERATIONS.md): respaldos locales, reversión, migración de repositorios y tareas pendientes.

## 7. Referencia técnica

- [Oracle VirtualBox 7.2 — Networking: NAT](https://www.virtualbox.org/manual/ch06.html)
- [Oracle VirtualBox 7.2 — VBoxManage modifyvm, NAT LocalhostReachable](https://www.virtualbox.org/manual/ch08.html#vboxmanage-modifyvm)
- [Microsoft Learn — Windows Defender Firewall](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/)
- [Microsoft Learn — SMB signing](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing)
- [Microsoft Learn — Controlled Folder Access](https://learn.microsoft.com/en-us/defender-endpoint/controlled-folder-access)
