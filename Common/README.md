# Auditores compartidos

## Microsoft Defender — Windows 10 y Windows 11

[Defender-Protection-Audit.ps1](./Defender-Protection-Audit.ps1) es un auditor de solo lectura compatible con Windows 10/11 cliente y Windows PowerShell 5.1.

### Uso

```powershell
.\Defender-Protection-Audit.ps1
.\Defender-Protection-Audit.ps1 -Mode Report
.\Defender-Protection-Audit.ps1 -Mode Report -OutputDirectory 'D:\HardeningReports'
```

### Inventario

- Estado de Microsoft Defender Antivirus y protección en tiempo real.
- Behavior Monitoring, IOAV, On-access y Tamper Protection.
- Modo de ejecución, versión del motor y antigüedad de firmas.
- Flags de desactivación de protecciones.
- PUA Protection, Controlled Folder Access y Network Protection.
- Reglas ASR y sus acciones (Block, Audit, Disabled, Warn o Not configured).
- Recuento de exclusiones antivirus, ASR y Controlled Folder Access.

Los valores se presentan como evidencia observada, no como certificación. Audit/Warn no equivalen a enforcement. Una regla ASR deshabilitada puede responder a una decisión de compatibilidad o administración; el auditor no la activa.

Los informes no incluyen los paths concretos de exclusiones ni las aplicaciones permitidas: solo sus cantidades, para reducir la exposición accidental de información local. Los informes sí incluyen nombre del equipo y postura de seguridad; deben protegerse y sanearse antes de compartirlos.

### Límites

- No ejecuta Set-MpPreference, Add-MpPreference ni Remove-MpPreference.
- No cambia Defender, firewall, servicios, Registro ni políticas.
- No agrega exclusiones ni modifica reglas ASR.
- No sustituye Microsoft Defender for Endpoint, Intune, Group Policy ni herramientas de administración empresarial.
- Algunas propiedades dependen de la edición, build, versión del motor o producto antivirus activo.
