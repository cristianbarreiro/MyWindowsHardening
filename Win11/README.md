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
