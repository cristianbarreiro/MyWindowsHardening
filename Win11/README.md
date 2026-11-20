# Windows 11

Baseline general diseñado específicamente para Windows 11 cliente.

**Estado:** núcleo de auditoría de solo lectura v0.1.0-bootstrap. No aplica cambios al equipo.

## Baseline general

- [Win11-Hardening-20261119.ps1](./Win11-Hardening-20261119.ps1) — inventario de seguridad y configuración de Windows 11.
  
No copiar ni ejecutar automáticamente los scripts de `Win10/` en Windows 11. Este script tiene comprobaciones propias para builds 22000+, Device Guard/VBS, Secure Boot, TPM y controles de plataforma de Windows 11.

## Uso

```powershell
# Auditoría predeterminada
.\Win11-Hardening-20261119.ps1

# Validar e inventariar
.\Win11-Hardening-20261119.ps1 -Mode Validate

# Elegir carpeta de informes
.\Win11-Hardening-20261119.ps1 -Mode Report -OutputDirectory 'D:\HardeningReports'
```

Los informes JSON, CSV y TXT se guardan en `Reports` junto al script, salvo que se indique `OutputDirectory`.

## Qué inspecciona

- Versión, edición, build y arquitectura de Windows.
- Estado del ciclo de vida de Windows 11, separado de la compatibilidad técnica del auditor. Distingue fechas de fin de actualizaciones por versión y familia de edición para 23H2, 24H2, 25H2, 26H1 y 26H2; las combinaciones no reconocidas se marcan como `REVIEW` y requieren verificación manual.
- Windows Defender Firewall y Microsoft Defender.
- Indicadores de UAC, SmartScreen, AutoRun, LSA protection y Credential Guard configurados en el Registro.
- Secure Boot, TPM y estado de Device Guard/VBS cuando la plataforma expone esos datos.
- Configuración SMB Client y SMB Server, si están disponibles los cmdlets.
- Servicios seleccionados de red, descubrimiento, impresión, virtualización, WSL, Defender y acceso remoto.
- Adaptadores y perfiles de conexión.
- Estado de BitLocker y Delivery Optimization, si están disponibles sus cmdlets.

## Garantías y límites

- Auditoría estrictamente de solo lectura: no cambia Registro, firewall, servicios, SMB, Defender, BitLocker ni políticas.
- Los modos `Apply` y `Restore` están bloqueados explícitamente.
- No requiere elevación para iniciar la auditoría; algunas comprobaciones pueden devolver `UNAVAILABLE` según permisos, firmware o edición.
- Los valores de Registro se muestran como indicadores de configuración, no como prueba definitiva de que una protección esté activa.
- La disponibilidad de Secure Boot depende del firmware y del modo de arranque. VBS, Credential Guard y Memory Integrity dependen de hardware, edición, políticas y configuración.
- Los estados `PASS`, `REVIEW`, `FAIL`, `ERROR`, `INFO` y `UNAVAILABLE` son resultados de inventario; no constituyen una certificación de seguridad.

## Evolución

Los módulos de aplicación se incorporarán por separado, después de definir alcance, compatibilidad por build/edición, backup, aplicación idempotente, rollback y validación. La auditoría inicial no debe interpretarse como una recomendación automática para cambiar los valores observados.


### Ciclo de vida y mantenimiento de la tabla

La comprobación de mantenimiento compara la fecha local del equipo con las fechas de fin de actualizaciones publicadas por Microsoft para la versión y edición detectadas. Un resultado `FAIL` en la categoría `Servicing` indica que se superó la fecha publicada de fin de actualizaciones; no significa que el auditor sea técnicamente incompatible. El auditor sigue siendo de solo lectura.

La tabla es una referencia versionada, no una consulta en tiempo real. Debe revisarse cuando Microsoft actualice Windows release health o Lifecycle. Se contemplan explícitamente Windows 11 Enterprise LTSC 2024 e IoT Enterprise LTSC 2024. Si la combinación de versión/edición no está contemplada, el resultado será `REVIEW`, nunca una afirmación automática de soporte.

Fuentes oficiales: [Windows 11 release information](https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information), [Windows 11 Home and Pro lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-11-home-and-pro) y [Windows 11 24H2 release health](https://learn.microsoft.com/en-us/windows/release-health/status-windows-11-24H2).
