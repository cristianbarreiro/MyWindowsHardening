# Win10-Hardening-20261113.ps1

**Versión:** 0.1.0-bootstrap  
**Fecha inicial:** 13/11/2026  
**Compatibilidad:** Windows 10 cliente, Windows PowerShell 5.1  
**Estado:** auditoría de solo lectura.

## Objetivo

Construir un baseline general, reutilizable y progresivo para Windows 10. El script principal será el punto de entrada; los controles se incorporarán por módulos independientes y con alcance explícito.

Esta primera entrega establece el núcleo de inventario y reportes. No modifica ninguna configuración del equipo.

## Uso

~~~powershell
# Auditoría predeterminada
.\Win10-Hardening-20261113.ps1

# Validar e inventariar
.\Win10-Hardening-20261113.ps1 -Mode Validate

# Elegir carpeta de informes
.\Win10-Hardening-20261113.ps1 -Mode Report -OutputDirectory 'D:\HardeningReports'
~~~

Los informes JSON, CSV y TXT se guardan en Reports junto al script, salvo que se indique OutputDirectory.

## Qué inspecciona

- Versión, edición y build de Windows.
- Perfiles de Windows Defender Firewall y políticas predeterminadas.
- Estado básico de Microsoft Defender.
- Configuración SMB Client y SMB Server, si están disponibles los cmdlets.
- Servicios seleccionados relacionados con SMB, descubrimiento, Wi-Fi, Delivery Optimization, impresión, virtualización y WSL.
- Adaptadores y perfiles de conexión.
- Estado de BitLocker, si los cmdlets están disponibles.
- Modo de Delivery Optimization, si está disponible.

Los estados PASS, REVIEW, FAIL, ERROR, INFO y UNAVAILABLE describen comprobaciones técnicas. Muchos resultados son INFO y no equivalen a una recomendación automática ni a una certificación de seguridad.

## Garantías de seguridad de esta versión

- No ejecuta comandos Set-*, Enable-*, Disable-* ni Stop-Service.
- No cambia Registro, ACL, firewall, rutas, VPN, servicios, VirtualBox ni cifrado.
- Apply y Restore están bloqueados explícitamente.
- No requiere elevación para ejecutar la auditoría.
- No recopila contraseñas, claves, cookies ni contenido personal de archivos.

## Compatibilidad y límites

El script está escrito para Windows PowerShell 5.1 y Windows 10 cliente. Windows 11 queda fuera de alcance. Builds anteriores a 19045 se marcan para revisión de compatibilidad. La ausencia de cmdlets se informa; el script no instala componentes ni cambia políticas para compensarlo.

La auditoría no certifica que el equipo esté protegido. Produce una línea base para diseñar las siguientes fases.

## Evolución modular

1. Firewall.
2. Defender y ASR.
3. Identidad, NTLM y SMB.
4. Servicios y reducción de superficie.
5. Red y aislamiento de virtualización.
6. Privacidad y funciones opcionales.
7. Almacenamiento y cifrado.
8. Validación integral.

Cada módulo futuro necesitará auditoría previa, matriz de compatibilidad, estado deseado, backup específico, aplicación idempotente, rollback probado y validación posterior.

Los perfiles especializados existentes no se ejecutarán automáticamente desde el núcleo. Primero habrá que eliminar duplicaciones y definir la propiedad de cada control.

## Versionado

- 0.1.x: inventario y reportes de solo lectura.
- 0.2.x: primer módulo de aplicación, después de revisión y pruebas.
- 1.0.0: baseline con módulos revisados, reversión verificada y compatibilidad documentada.

## Próximo paso

Ejecutar el auditor en una VM limpia de Windows 10 y comparar los resultados con un equipo real. No habilitar Apply hasta que exista un módulo completo y probado.
