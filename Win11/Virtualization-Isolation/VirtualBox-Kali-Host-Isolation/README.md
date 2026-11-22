# Windows 11 — VirtualBox / Kali Host Isolation

<sup>Perfil de aislamiento entre una VM Kali Linux y un host Windows 11 · VirtualBox NAT</sup>

**Estado:** diseño técnico para Windows 11; pendiente de validación práctica en un host Windows 11.  
**Host objetivo:** Windows 11 cliente, build 22000 o posterior.  
**Hipervisor:** Oracle VirtualBox; registrar versión exacta en cada validación.

> No afirma que la configuración de Windows 10 haya sido aplicada o validada en Windows 11. No es un instalador genérico. No copiar reglas, servicios deshabilitados ni estados de adaptadores desde Win10 sin auditar el equipo.

## 1. Objetivo
Reducir las vías por las que un proceso dentro de Kali puede iniciar conexiones hacia servicios del host Windows, acceder a recursos compartidos o aprovechar integraciones Guest↔Host innecesarias.

El diseño conserva NAT para permitir conectividad saliente. NAT no es un air gap, no garantiza aislamiento frente a destinos de la LAN y no protege frente a vulnerabilidades del hipervisor.

## 2. Inventario obligatorio

| Área | Datos |
|---|---|
| Windows | Edición, versión, build, UBR, arquitectura y actualizaciones |
| Seguridad de plataforma | Secure Boot, TPM, VBS, Credential Guard, Memory Integrity/HVCI |
| VirtualBox | Versión, extensiones instaladas y Guest Additions |
| VM | Nombre, versión de Kali, snapshots y discos |
| Red | Adaptadores 1–8, modo NAT/Bridged/Host-Only/Internal, MAC y rutas |
| Integraciones | Shared Folders, Shared Clipboard, Drag and Drop, USB, audio, webcam y 3D |
| Firewall | Perfiles activos, políticas efectivas y reglas VirtualBox |
| Servicios | Servicios de red y descubrimiento; comprobar dependencias |

## 3. Topología recomendada
Para una VM de laboratorio que solo necesita acceso saliente:
- Adaptador 1: NAT.
- Adaptadores 2–8: desconectados (none), salvo requisito documentado.
- Evitar Bridged si no se necesita que Kali sea visible directamente en la LAN.
- Evitar Host-Only si no se necesita comunicación host↔guest.
- No habilitar NAT port forwarding salvo necesidad documentada.

NAT permite conexiones iniciadas desde Kali hacia redes accesibles por el host. No debe describirse como aislamiento completo de la LAN.

## 4. Integraciones Guest↔Host
Deshabilitar si no son necesarias:
- Shared Folders.
- Shared Clipboard (bidireccional).
- Drag and Drop (bidireccional).
- USB passthrough.
- Webcam/audio passthrough cuando no se utilicen.
- Aceleración 3D si no es requerida.

Mantener VirtualBox y Guest Additions actualizados. Deshabilitar integraciones reduce canales de intercambio, pero no constituye una barrera frente a una vulnerabilidad de escape.

## 5. Windows 11: controles que deben preservarse
No deshabilitar globalmente como medida genérica:
- Virtualization-Based Security (VBS).
- Hypervisor-Protected Code Integrity (HVCI / Memory Integrity).
- Credential Guard.
- Secure Boot y TPM.
- Hyper-V, Virtual Machine Platform y Windows Hypervisor Platform.
- WSL2 y servicios HNS/Host Network Service cuando estén en uso.

VirtualBox puede funcionar con el hipervisor de Windows mediante mecanismos de compatibilidad, aunque rendimiento y capacidades varían por versión. No desactivar Hyper-V/VBS para resolver rendimiento sin evaluar impacto de seguridad y documentación de Oracle.

## 6. Firewall y servicios
- Mantener perfiles de Windows Defender Firewall habilitados.
- Inspeccionar reglas activas y su origen (local, GPO, MDM).
- Mantener política de entrada restrictiva definida por la organización.
- No crear bloqueos globales de subredes NAT sin comprobar el efecto sobre otros adaptadores y servicios.
- No deshabilitar indiscriminadamente LanmanServer, LanmanWorkstation, SharedAccess, HNS, vmcompute, WlanSvc, Spooler ni servicios VirtualBox.
- Si el host no debe ofrecer SMB, tratarlo como control independiente y validar shares, impresoras y dependencias.

Una regla de entrada al host desde la red NAT puede ser una capa adicional, pero debe basarse en la subred real observada. No bloquea por sí sola la comunicación saliente del invitado hacia la LAN.

## 7. Auditoría inicial (solo lectura)

~~~powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Select-Object ProductName, DisplayVersion, CurrentBuild, UBR, EditionID
Get-CimInstance Win32_ComputerSystem | Select-Object HypervisorPresent
Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue | Select-Object VirtualizationBasedSecurityStatus, SecurityServicesConfigured, SecurityServicesRunning
Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
Get-NetAdapter -IncludeHidden | Select-Object Name, InterfaceDescription, Status, MacAddress
Get-CimInstance Win32_Service | Where-Object Name -in @('VBoxSDS','vmcompute','vmms','WslService','SharedAccess','hns','LanmanServer','LanmanWorkstation') | Select-Object Name, State, StartMode
Get-SmbServerConfiguration -ErrorAction SilentlyContinue | Select-Object EnableSMB1Protocol, EnableSMB2Protocol, RequireSecuritySignature
Get-SmbClientConfiguration -ErrorAction SilentlyContinue | Select-Object RequireSecuritySignature, EnableSecuritySignature
~~~

Consultar también VirtualBox:

~~~powershell
VBoxManage list vms
VBoxManage showvminfo "NOMBRE_DE_LA_VM" --machinereadable
~~~

Inspeccionar nic1–nic8, clipboard, draganddrop, usb, sharedfolders, accelerate3d y reglas NAT. No asumir que los valores por defecto son iguales entre versiones.

## 8. Validación desde Kali
- Revisar interfaces: ip -br address.
- Revisar rutas: ip route.
- Revisar DNS: resolvectl status o la configuración DNS disponible.
- Confirmar conectividad saliente esperada.
- Comprobar que no hay interfaces Bridged/Host-Only inesperadas.
- Verificar que no se accede a servicios del host que deban permanecer aislados.
- Repetir pruebas tras reiniciar VM y host.

Las direcciones 10.0.2.2 y 10.0.2.3 suelen ser gateway y DNS de NAT en VirtualBox, pero deben confirmarse en la VM real. No inferir que el tráfico sale por una VPN porque haya una VPN instalada en Windows.

## 9. Qué no garantiza
No garantiza invisibilidad de VirtualBox, anonimato, IP pública independiente, bloqueo de conexiones salientes desde Kali, protección ante escape del hipervisor ni aislamiento si se habilitan integraciones Guest↔Host.

Para un air gap real, retirar la conectividad virtual o diseñar una red interna sin salida y validar que no exista otro camino.

## 10. Fuentes
- [Oracle VirtualBox — Networking](https://www.virtualbox.org/manual/ch06.html)
- [Oracle VirtualBox — VBoxManage modifyvm](https://www.virtualbox.org/manual/ch08.html#vboxmanage-modifyvm)
- [Microsoft Learn — Virtualization-based security](https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity)
- [Microsoft Learn — Windows Defender Firewall](https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/)

**Advertencia:** mantener actualizado Windows 11, VirtualBox y Kali es parte del aislamiento. Las reglas de firewall no sustituyen los parches del hipervisor.
