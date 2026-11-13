# Validación — VirtualBox / Kali Host Isolation

## 1. Registro de la ejecución final

- **Fecha:** 13/11/2026.
- **Equipo:** Windows 10 Home Single Language x64, 22H2, build 19045.
- **Hipervisor:** VirtualBox 7.2.22r175245.
- **Tipo de ejecución:** auditoría final de solo lectura, posterior a la desactivación de las reglas entrantes de Antigravity IDE.
- **Directorio local del informe:** `KaliIsolated-Phase8-FinalValidation-20261113-011048`.
- **Exportación del firewall:** `Final-Firewall-Configuration.wfw`.

## 2. Resultado resumido

| Resultado | Cantidad |
|---|---:|
| PASS | 49 |
| REVIEW | 0 |
| FAIL | 0 |
| INFO | 3 |
| Warnings | 0 |

La auditoría no encontró fallos en los controles que comprobó. Los tres elementos INFO no representan fallos. El resultado corresponde a ese equipo y momento; después de Windows Update, cambios de aplicaciones, drivers, VPN o VirtualBox hay que volver a validar.

## 3. Firewall

| Control | Estado comprobado |
|---|---|
| Domain / Private / Public | Todos Enabled |
| Default inbound | Block |
| Default outbound | Allow |
| Logging de bloqueos | Enabled |
| Reglas explícitamente deshabilitadas | 15 verificadas en PersistentStore y ActiveStore |
| Reglas personalizadas de bloqueo | Las tres esperadas activas |

Reglas personalizadas confirmadas:

1. `Kali-Isolated - Block VirtualBox NAT inbound`.
2. `Kali-Isolated - Block SMB TCP Inbound`.
3. `Kali-Isolated - Block NetBIOS UDP Inbound`.

Las 15 excepciones entrantes explícitamente deshabilitadas correspondían a:

- Spotify: 9 reglas.
- Slack: 1 regla.
- Correo y Calendario UWP: 1 grupo/regla.
- Xbox Game Bar: 1 grupo/regla.
- Microsoft Store: 1 grupo/regla.
- Antigravity IDE: 2 reglas (TCP y UDP).

En el último recuento había 124 reglas entrantes Allow activas; 59 conservaban perfil Public/Any. Se mantuvieron deliberadamente. Su clasificación observada fue: Core Networking (19), HNS/ICS/DNS (34), FrameServer (2), Windows Backup Client (2) y UWP (2: Windows Feature Experience Pack y Desktop App Web Viewer). No se debe tomar la presencia de 59 reglas como razón para deshabilitarlas en bloque: cada una requiere identificar servicio, paquete, interfaz y dependencia.

## 4. Servicios

| Servicio | Estado | Inicio |
|---|---|---|
| DoSvc | Running | Automatic |
| FDResPub | Stopped | Disabled |
| fdPHost | Stopped | Disabled |
| SSDPSRV | Stopped | Disabled |
| upnphost | Stopped | Disabled |
| LanmanServer | Stopped | Disabled |
| LanmanWorkstation | Running | Automatic |
| HNS | Running | Manual |
| SharedAccess | Running | Manual |
| Spooler | Running | Automatic |
| VBoxSDS | Running/available | Manual |
| vmcompute | Running/available | Manual |
| WlanSvc | Running | Automatic |
| WSLService | Running/available | Automatic |

Los estados pueden cambiar durante el ciclo de vida del sistema. En particular, no deshabilitar HNS, SharedAccess, vmcompute, WSLService, VBoxSDS o WlanSvc sin un análisis separado de dependencias.

## 5. SMB

Valores confirmados:

| Propiedad | Valor |
|---|---|
| EnableSMB1Protocol (Server) | False |
| EnableSMB2Protocol (Server: SMB 2/3) | False |
| RequireSecuritySignature (Client) | True |
| EnableInsecureGuestLogons (Client) | False |
| LanmanServer | Stopped / Disabled |
| LanmanWorkstation | Running / Automatic |

También se confirmó binding `ms_server` deshabilitado y `ms_msclient` conservado durante la fase de aplicación.

### Listener TCP 445

La auditoría observó `::445` asociado a PID 4 (System). El listener persistía pese a que SMB Server estaba deshabilitado y los protocolos Server estaban en False. PID 4 por sí solo no demuestra que se estén publicando recursos compartidos. No se deshabilitaron drivers de kernel de forma indiscriminada.

## 6. Microsoft Defender

| Control | Resultado |
|---|---|
| Antivirus | True |
| Real-time protection | True |
| Behavior Monitor | True |
| IOAV | True |
| Network Inspection System | True |
| Tamper Protection | True |
| PUA Protection | 1 (Enabled) |
| Controlled Folder Access | 1 (Enabled) |
| Network Protection | 2 (Audit Mode) |

Network Protection permanece en Audit Mode y no se contabiliza como enforcement. CFA protege las ubicaciones predeterminadas de Windows; D:\Dev\GitHub no se agregó a la lista de carpetas protegidas.

No se observaron eventos CFA 1123/1124/1127/1128 después de la activación durante el período de comprobación. Los eventos 1124 revisados antes de la activación se asociaron a Git fsmonitor en ubicaciones antiguas de repositorios. La ausencia de eventos durante el período observado no es una garantía de que nunca vaya a ocurrir un bloqueo.

## 7. Delivery Optimization

- `DoSvc`: Running / Automatic.
- `Get-DODownloadMode`: `CdnOnly`.
- Dos reglas entrantes de firewall para Delivery Optimization TCP/UDP 7680 deshabilitadas.
- No se detuvo DoSvc ni se limpió la caché.

## 8. Red y VirtualBox

| Control | Resultado |
|---|---|
| Ethernet2 / Ethernet3 (VirtualBox Host-Only) | Disabled |
| Binding `oracle_VBoxNetLwf` | 0 habilitados / 4 encontrados |
| Wi-Fi | Up / perfil Public |
| CloudflareWARP | Up / perfil Public |
| VM Kali | NIC1 = nat; NIC2–8 = none |
| VM PrivGuard-W11-Manual | NIC1 = nat; NIC2–8 = none |

`LocalhostReachable=0` había sido configurado y verificado en una fase anterior; no se volvió a imprimir ese parámetro en el informe final de Phase 8. No se modificó la configuración NAT de las VM después de esa comprobación.

## 9. Listeners y observaciones de red

El informe registró:

- `::445` — PID 4/System.
- `::135` y `0.0.0.0:135` — svchost.
- DNS locales de WARP en `127.0.2.2` y `127.0.2.3`, asociados a `warp-svc`.
- No se observó listener WARP DNS en `0.0.0.0`/direcciones LAN.

La presencia de un listener debe interpretarse junto con el servicio propietario, bindings, reglas de firewall y configuración del protocolo. No se debe inferir exposición de SMB o RPC únicamente por el número de puerto.

## 10. Evidencia y límites

El informe local completo contiene los detalles de las comprobaciones y la exportación final del firewall. La evidencia registrada aquí es un resumen fiel de esa ejecución; no es una telemetría continua ni un certificado de seguridad.

La auditoría final no volvió a comprobar explícitamente todos los detalles de integración de VirtualBox (carpetas compartidas, portapapeles, drag-and-drop y 3D); esos controles se habían configurado en fases previas y no fueron modificados después. Revalidarlos después de una actualización de VirtualBox o una importación/clonación de VM.

### Criterio de repetición

Repetir auditoría cuando ocurra cualquiera de estos eventos:

- Windows Update o cambios de build.
- Actualización/reinstalación de VirtualBox o Guest Additions.
- Cambio de adaptadores, perfiles de red, Wi-Fi, hotspot, VPN o WARP.
- Instalación/desinstalación de aplicaciones con reglas de firewall.
- Cambios en SMB, Defender, CFA, Delivery Optimization o servicios.
- Importación, clonación o modificación de una VM.
