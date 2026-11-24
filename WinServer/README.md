# Windows Server

Auditor empresarial inicial de solo lectura para Windows Server 2016, 2019, 2022 y 2025.

## Baseline general

- [WinServer-Hardening-20261121.ps1](./WinServer-Hardening-20261121.ps1) — inventario de seguridad, roles y exposición.
- Versión inicial: `0.1.0-bootstrap`.
- Compatibilidad declarada: Windows PowerShell 5.1.

## Uso

```powershell
.\WinServer-Hardening-20261121.ps1
.\WinServer-Hardening-20261121.ps1 -Mode Validate
.\WinServer-Hardening-20261121.ps1 -Mode Report -OutputDirectory 'D:\HardeningReports'
```

Los informes se generan en JSON, CSV y TXT. Pueden contener nombre de host, dominio, miembros de Administrators, roles instalados, listeners y postura de seguridad. Protegé los informes y sanealos antes de compartirlos.

## Áreas inventariadas

- Versión, edición, build, arquitectura, dominio y producto Windows Server.
- Perfiles y políticas predeterminadas de Windows Defender Firewall.
- Estado básico de Microsoft Defender.
- Indicadores UAC, LSA protection, Credential Guard, VBS, NTLM y RDP.
- Configuración SMB Client y Server.
- Roles y características instalados.
- Indicadores de Active Directory cuando existe el módulo correspondiente.
- Servicios relevantes para roles comunes.
- Miembros de Administrators local.
- Adaptadores físicos y listeners TCP.
- Estado de BitLocker.
- Política de auditoría de Windows.
- Indicadores heurísticos de reinicio pendiente.

## Garantías y límites

- Auditoría estrictamente de solo lectura.
- Los modos Apply y Restore están bloqueados.
- No deshabilita roles, servicios, firewall, protocolos SMB ni políticas.
- La presencia de un servicio o listener no se interpreta automáticamente como una vulnerabilidad.
- La clasificación de miembros de Administrators requiere una política esperada para cada rol; los resultados REVIEW necesitan validación humana.
- El listado de listeners se limita a los primeros 100 endpoints en esta versión.
- La compatibilidad técnica no confirma que la versión de Windows Server siga recibiendo actualizaciones.

## Próxima evolución

1. Validación de servicing por edición y canal.
2. Perfiles separados de Member Server, Domain Controller, File Server e IIS.
3. Evaluación de políticas efectivas y procedencia (local, GPO o MDM).
4. Correlación de listeners con procesos, servicios y reglas de firewall.
5. Pruebas automatizadas de funciones de inventario y reportes.

Este auditor es una línea base inicial, no una baseline de configuración para aplicar a todos los roles empresariales.
