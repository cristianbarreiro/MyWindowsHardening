# Alcance técnico — VirtualBox / Kali Host Isolation

## 1. Identidad del perfil

- **Sistema anfitrión:** Windows 10 22H2, build 19045.
- **Edición probada:** Home Single Language x64.
- **Hipervisor:** Oracle VirtualBox 7.2.22r175245.
- **Invitado principal:** Kali Linux 2026.3.
- **Objetivo:** reducir la superficie de comunicación entre el invitado y el host.
- **Tipo:** hardening local y defensa en profundidad. No es un sandbox certificado ni un air gap.

## 2. Modelo de amenazas

El perfil reduce principalmente estos caminos:

1. Conexiones entrantes no solicitadas desde la red NAT de VirtualBox hacia servicios del host.
2. Exposición de SMB/NetBIOS del host a la red.
3. Acceso al loopback del host a través del gateway especial de NAT.
4. Conectividad accidental mediante adaptadores Host-Only o Bridged.
5. Transferencia de datos mediante carpetas compartidas, portapapeles o drag-and-drop.
6. Descubrimiento de recursos/servicios del host mediante UPnP, SSDP, mDNS, NetBIOS, WFD, DIAL, PlayTo y proximidad.
7. Exposición innecesaria de aplicaciones del host mediante reglas entrantes amplias.
8. Modificación o lectura de carpetas protegidas de Windows mediante procesos que se ejecutan en el host.

## 3. Controles aplicados

| Control | Configuración observada | Alcance |
|---|---|---|
| Firewall Windows | Domain/Private/Public Enabled; inbound Block; outbound Allow; log blocked activo | Filtrado de conexiones del host |
| Regla NAT | Bloqueo de entrada desde 10.0.2.0/24 al host | Entrada desde la red NAT a Windows |
| SMB Server | LanmanServer Stopped/Disabled; SMB1 y SMB2/3 Server False | Desactivar el rol de servidor SMB |
| SMB Client | LanmanWorkstation Running/Automatic; firma requerida; guest inseguro False | Mantener uso de recursos SMB remotos |
| SMB/NetBIOS | Bloqueo entrante TCP 139/445 y UDP 137/138 | Reducir superficie de entrada |
| Binding | ms_server Disabled; ms_msclient conservado | Deshabilitar componente servidor, mantener cliente |
| VirtualBox NICs | NIC1 NAT; NIC2–8 None en las dos VM auditadas | Evitar Host-Only/Bridged en las VM |
| Host-Only | Ethernet2/Ethernet3 deshabilitados, no eliminados | Deshabilitar adaptadores host-only conocidos |
| Bridged filter | oracle_VBoxNetLwf deshabilitado en todos los adaptadores encontrados | Evitar bridge desde adaptadores del host |
| NAT localhost | LocalhostReachable=0 | Deshabilitar el camino de NAT hacia loopback del host |
| Integraciones VM | Shared folders, shared clipboard y drag-and-drop deshabilitados; 3D Off | Reducir canales Guest↔Host |
| Discovery | Servicios y grupos de reglas seleccionados detenidos/deshabilitados | Reducir anuncio/descubrimiento de recursos |
| Wireless/remote | Reglas entrantes de WFD, DIAL, PlayTo, proximidad y Remote Assistance deshabilitadas | Reducir exposición de funciones no utilizadas |
| Delivery Optimization | CdnOnly; servicio conservado; dos reglas inbound 7680 deshabilitadas | Desactivar el modo de intercambio P2P observado |
| Defender | Antivirus, RTP, comportamiento, IOAV, NIS y Tamper Protection activos | Protección del host |
| CFA | Enabled | Protección de carpetas controladas |
| Network Protection | Audit Mode | Telemetría/auditoría, no enforcement |

## 4. Controles deliberadamente preservados

No se deshabilitaron indiscriminadamente los componentes que sostienen conectividad, virtualización, desarrollo o copias de seguridad:

- `WlanSvc`, para Wi-Fi.
- `Spooler`, aunque el equipo no utilice impresoras de red.
- `VBoxSDS`, `vmcompute`, HNS, WSL y `SharedAccess`.
- `LanmanWorkstation`, porque Windows debe continuar como cliente SMB.
- reglas de Core Networking.
- reglas HNS/ICS/DNS, aunque algunas estén asociadas a GUID de interfaces antiguas.
- reglas de FrameServer con alcance LocalSubnet.
- reglas Windows Backup Client.
- reglas de Windows Feature Experience Pack y Desktop App Web Viewer.
- adaptador, rutas y Advanced Kill Switch de Proton VPN.
- Cloudflare WARP y su servicio; no se alteraron sus rutas ni sus adaptadores.

El hecho de que una regla pertenezca a HNS/ICS o esté asociada a una interfaz que parece antigua no basta para borrarla. Se conserva hasta identificar con precisión su dependencia.

## 5. Qué queda fuera del alcance

| Área | ¿Lo garantiza este perfil? | Motivo |
|---|---|---|
| Aislamiento completo de LAN | No | NAT permite conexiones salientes y destinos alcanzables mediante el host. |
| Air gap | No | La VM conserva NAT e Internet. |
| Escape del hipervisor | No | Una vulnerabilidad de VirtualBox o del host puede romper el límite. |
| Invisibilidad de la VM | No | El invitado puede exponer indicios de hardware virtual/VirtualBox. |
| Ocultar Windows de manera absoluta | No | Se reduce la exposición directa, pero no se promete ausencia de toda inferencia o fuga. |
| Separar IP pública sin VPN | No | NAT comparte la salida de red del host. |
| Anonimato | No | IP, sesión, cookies, cuenta, dispositivo y datos de pago son señales independientes. |
| Protección frente a una VM comprometida | Parcial | Se restringe la entrada al host; no se bloquea universalmente la salida del invitado. |
| Cifrado C: y D: | No | No se ha aplicado cifrado de disco en esta fase. |
| ESU / Windows Update | No | Debe verificarse por separado la cobertura de actualizaciones. |
| Firewall de salida restrictivo | No | La política global de salida permanece Allow. |
| Endpoint protection dentro de Kali | No | Este perfil administra el host, no sustituye el hardening del invitado. |

## 6. NAT: interpretación correcta

VirtualBox NAT permite que el invitado inicie conexiones hacia destinos externos a través de la conectividad del anfitrión. En una configuración NAT típica, el invitado puede identificar una puerta de enlace virtual como `10.0.2.2` y un DNS virtual como `10.0.2.3`.

En esta implementación se estableció `LocalhostReachable=0`, lo que deshabilita la función especial que permite que el invitado se conecte al loopback del anfitrión por esa ruta NAT.

La regla de Windows que bloquea la subred `10.0.2.0/24` protege la entrada al host desde esa red. No debe interpretarse como una regla que impide a Kali iniciar cualquier conexión hacia otros equipos de la LAN. El resultado depende de la topología, rutas, NAT, firewall del host y firewall del destino.

## 7. Solicitudes web, IP y VPN

- Una solicitud del navegador en Kali se origina en Kali y normalmente revela las características de ese navegador/sistema invitado.
- El sitio no recibe automáticamente acceso a procesos, archivos, cookies o aplicaciones de Windows.
- El hardware virtual puede permitir reconocer VirtualBox; eso no equivale a leer el sistema operativo host.
- Sin VPN independiente en Kali, la IP pública de salida puede coincidir con la del host.
- Si se usa una VPN dentro de Kali, verificar desde Kali la IP de salida, DNS y ruta efectiva.
- La VPN instalada en Windows no demuestra por sí sola que el invitado esté protegido por esa VPN: puede depender del enrutamiento y del split tunneling.
- Cambiar de Wi-Fi a hotspot móvil cambia el proveedor/red de salida, pero NAT continúa sin asignar una IP pública independiente a la VM.
- La IP o la VPN no ocultan la identidad que se entrega a un servicio mediante login, cookies, datos personales o una transferencia.

## 8. Riesgos y compatibilidad

- Deshabilitar reglas entrantes de una aplicación puede afectar características de descubrimiento o conexión desde otros dispositivos; probar el uso local y remoto que realmente se necesite.
- Apagar SMB Server no impide que Windows use SMB Client, pero desactiva el servicio servidor que comparte archivos/impresoras.
- Un listener TCP 445 perteneciente a PID 4 no es evidencia suficiente de shares publicados. Correlacionar servicios, protocolos SMB Server, bindings y reglas.
- Network Protection quedó en Audit Mode. No debe contarse como prevención efectiva.
- CFA no se extendió a D:\Dev\GitHub porque las herramientas de desarrollo requieren escrituras. No agregar excepciones globales para `git.exe` sin una evaluación específica.
- El perfil se probó en un único host; los nombres de adaptadores, reglas, paquetes y servicios pueden variar.
- Cualquier cambio de VirtualBox, Windows, VPN o topología requiere repetir la validación.

## 9. Criterio de aceptación

La implementación se considera validada para el estado observado el 13/11/2026 porque la auditoría final obtuvo 49 PASS, 0 REVIEW y 0 FAIL, con 3 INFO. Ese resultado es una fotografía del equipo y no una garantía permanente. Los criterios y resultados concretos están en [VALIDATION.md](./VALIDATION.md).
