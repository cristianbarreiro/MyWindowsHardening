# Windows 11

Baseline general diseñado específicamente para Windows 11 cliente.

**Estado:** núcleo de auditoría de solo lectura v0.1.0-bootstrap. No aplica cambios al equipo.

## Baseline general
- [Win11-Hardening-20261119.ps1](./Win11-Hardening-20261119.ps1) — inventario de seguridad y configuración de Windows 11.

No copiar ni ejecutar automáticamente los scripts de Win10 en Windows 11. Este baseline tiene comprobaciones propias para builds 22000+, Device Guard/VBS, Secure Boot, TPM y controles de plataforma de Windows 11.

## Uso
~~~powershell
.\Win11-Hardening-20261119.ps1
.\Win11-Hardening-20261119.ps1 -Mode Validate
.\Win11-Hardening-20261119.ps1 -Mode Report -OutputDirectory 'D:\HardeningReports'
~~~

Los informes JSON, CSV y TXT se guardan en Reports junto al script, salvo que se indique OutputDirectory.

## Perfiles especializados

| Dominio | Perfil | Estado |
|---|---|---|
| [Network-Authentication](./Network-Authentication/README.md) | [Outlook / NTLM / SMB — CVE-2026-124194](./Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md) | Diseño y auditoría documentados; Apply/Restore pendiente de validación |
| [Virtualization-Isolation](./Virtualization-Isolation/README.md) | [VirtualBox / Kali Host Isolation](./Virtualization-Isolation/VirtualBox-Kali-Host-Isolation/README.md) | Diseño documentado; validación práctica Windows 11 pendiente |

## Qué inspecciona el baseline
- Versión, edición, build y arquitectura de Windows.
- Estado del ciclo de vida de Windows 11.
- Windows Defender Firewall y Microsoft Defender.
- Indicadores de UAC, SmartScreen, AutoRun, LSA protection y Credential Guard.
- Secure Boot, TPM y Device Guard/VBS cuando la plataforma expone esos datos.
- Configuración SMB Client y SMB Server.
- Servicios seleccionados de red, descubrimiento, impresión, virtualización, WSL, Defender y acceso remoto.
- Adaptadores y perfiles de conexión.
- Estado de BitLocker y Delivery Optimization, si están disponibles sus cmdlets.

## Garantías y límites
- Auditoría estrictamente de solo lectura: no cambia Registro, firewall, servicios, SMB, Defender, BitLocker ni políticas.
- Los modos Apply y Restore están bloqueados explícitamente.
- No requiere elevación para iniciar la auditoría; algunas comprobaciones pueden devolver UNAVAILABLE según permisos, firmware o edición.
- Los valores de Registro son indicadores de configuración, no prueba definitiva de protección activa.
- Los estados PASS, REVIEW, FAIL, ERROR, INFO y UNAVAILABLE son resultados de inventario; no constituyen certificación de seguridad.

## Evolución
Los módulos de aplicación se incorporarán por separado, después de definir alcance, compatibilidad por build/edición, backup, aplicación idempotente, rollback y validación. Los perfiles especializados de esta carpeta no deben interpretarse como controles ya aplicados.

Fuentes oficiales: [Windows 11 release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information), [Windows 11 Home and Pro lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-11-home-and-pro) y [Windows 11 24H2 release health](https://learn.microsoft.com/en-us/windows/release-health/status-windows-11-24H2).
