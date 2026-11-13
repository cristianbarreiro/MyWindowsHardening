# Operaciones, backups y mantenimiento

## 1. Principio de cambio seguro

La implementación se realizó por fases. Cada grupo de cambios tuvo una copia previa o un mecanismo de reversión específico. No existe un único rollback universal que devuelva todo el host al estado anterior.

Antes de modificar el equipo:

1. Ejecutar una auditoría de solo lectura y guardar la salida.
2. Exportar el firewall y registrar los perfiles, reglas y excepciones.
3. Guardar los estados de servicios, bindings, adaptadores, VirtualBox y políticas Defender que se modificarán.
4. Crear un backup separado por fase.
5. Aplicar el cambio acotado.
6. Verificar PersistentStore y ActiveStore cuando corresponda.
7. Probar aplicaciones y conectividad.
8. Conservar el rollback hasta aprobar la validación final.

No ejecutar todos los scripts RESTORE en secuencia sin revisar el orden y el alcance. Un rollback antiguo puede reactivar una exposición que otra fase posterior había cerrado.

## 2. Inventario de copias locales

Las siguientes copias se conservaron en el equipo de validación. Las rutas absolutas dependen del perfil local; normalmente las carpetas de fases se ubicaron en el Escritorio y la copia CFA bajo ProgramData.

| Copia / carpeta | Contenido o propósito |
|---|---|
| `Firewall-Before-Kali-Hardening-20261112-194123.wfw` | Exportación del firewall anterior al hardening principal. |
| `KaliIsolated-SMB-20261112-200521` | Estado SMB previo y `RESTORE-SMB.ps1`. |
| `KaliIsolated-Phase3C-20261112-201610` | Estado previo de adaptadores Host-Only, filtro Bridged y configuración relacionada; incluye `RESTORE-PHASE3C.ps1`. |
| `KaliIsolated-Discovery-20261112-203219` | `Original-State.xml` y `RESTORE-DISCOVERY.ps1` para servicios de descubrimiento. |
| `KaliIsolated-Discovery-Firewall-20261112-203801` | `Firewall-Original-State.xml` y `RESTORE-FIREWALL.ps1`. |
| `KaliIsolated-WiFiProfile-20261112-204315` | Perfil Wi-Fi previo y `RESTORE-WIFI-PROFILE.ps1`. |
| `KaliIsolated-Wireless-DO-20261112-214235` | Estado previo de reglas Wireless Display/WFD, PlayTo, DIAL y TCP 7680; incluye `RESTORE-WIRELESS-DO.ps1`. |
| `KaliIsolated-Inbound-Exceptions-20261112-214719` | Estado previo de excepciones entrantes, mDNS, proximidad, AllJoyn, Remote Assistance y Tenorshare; incluye `RESTORE-INBOUND-EXCEPTIONS.ps1`. |
| `KaliIsolated-DO-CdnOnly-20261112-215014` | Estado anterior del modo Delivery Optimization y `RESTORE-DO-MODE.ps1`. |
| `KaliIsolated-Firewall-DO-20261112-230849` | Reglas inbound TCP/UDP 7680 y `RESTORE-DO-RULES.ps1`. |
| `KaliIsolated-D-Dev-ACL-20261112-222656` | SDDL original de D: y de D:\Dev, `RESTORE-D-ROOT-ACL.ps1`, y estado posterior de D:\Dev. |
| `KaliIsolated-Antigravity-Inbound-20261113-010557` | Estado previo de las dos reglas entrantes de Antigravity y `RESTORE-ANTIGRAVITY-INBOUND.ps1`. |
| `KaliIsolated-Phase8-FinalValidation-20261113-011048` | Informe final de solo lectura y `Final-Firewall-Configuration.wfw`. |
| `KaliIsolated\Defender\CFA\CFA-20261112-230116` bajo ProgramData | Estado previo de Controlled Folder Access y `RESTORE-CFA.ps1`. |

Las carpetas locales de backup son la evidencia operativa primaria. Este repositorio documenta su finalidad, pero no contiene los archivos locales ni sus scripts RESTORE.

## 3. Notas de reversión

- Restaurar solamente la fase que se desea revertir.
- Antes de ejecutar un rollback, leerlo y comparar el estado actual con el backup.
- Para el firewall, considerar que varias fases cambiaron reglas distintas. Restaurar un `.wfw` completo puede revertir también cambios posteriores ajenos a la fase.
- El backup CFA restaura la configuración previa de CFA (Audit Mode = 2); no debe ejecutarse si se desea mantener CFA Enabled.
- El rollback de ACL de D: restaura el SDDL guardado; no ejecutarlo como parte de una reversión de firewall o VirtualBox.
- Después de revertir, ejecutar una auditoría y volver a probar conectividad, SMB, VPN, WSL, VirtualBox y herramientas de desarrollo.

## 4. Migración de repositorios C: → D:

Esta operación se documenta como una medida de organización y separación de datos, no como sustituto del cifrado de disco.

- **Origen:** `C:\Users\<usuario>\Documents\GitHub`.
- **Destino:** `D:\Dev\GitHub`.
- Se conservaron 13 repositorios Git y la carpeta no Git `ExtensionesParaEdge`.
- La carpeta no Git tenía 5.872 archivos, 829 directorios y aproximadamente 0,686 GB.
- Robocopy copió 29.398 directorios y 286.253 archivos, aproximadamente 7,409 GB, sin errores reportados. El código de salida 1 indicó que hubo archivos copiados; la segunda verificación con `/L` no encontró archivos pendientes.
- Se compararon branch, HEAD, refs, estado limpio, remotes, upstream y Ahead/Behind de los 13 repositorios.
- 12 repositorios tenían remote configurado; `MCP-AntiSpam` no tenía remote.
- No se ejecutó fetch, pull, push, rebase ni sincronización remota como parte de la migración.
- El origen en C: se conservó; no se borró.
- D: tenía ACL explícitas Deny en la raíz para Users y Authenticated Users. Se retiraron temporalmente solo para crear D:\Dev y luego se restauró el SDDL original de la raíz. D:\Dev recibió Modify explícito para el usuario local con herencia.
- La copia se verificó por metadatos y estado Git; no se realizó verificación SHA-256 de cada archivo.

**Importante:** el cambio de ubicación no cifra los datos ni hace que D:\Dev\GitHub esté cubierto por CFA. No eliminar el origen hasta que se decida expresamente y exista otra copia de seguridad verificada.

## 5. Conservación de herramientas y servicios

El hardening preservó deliberadamente el entorno de desarrollo y virtualización:

- Java, Node.js, Python, XAMPP, Docker, Git, GitHub Desktop, VS Code y Antigravity IDE.
- Proton VPN y su Advanced Kill Switch.
- Cloudflare WARP.
- WSL/HNS y componentes de virtualización.
- VirtualBox y las VM auditadas.
- SMB Client de Windows.

La desactivación de reglas entrantes de una aplicación no equivale a desinstalarla ni a bloquear sus conexiones salientes. No se deben agregar excepciones de firewall amplias solo para eliminar avisos; primero identificar el flujo de red que la función necesita.

## 6. Convenciones para futuros scripts PowerShell

- Preferir un modo Audit de solo lectura antes del modo Apply.
- Ejecutar con elevación solamente cuando sea necesario.
- Crear backup antes de tocar servicios, firewall, Registro, bindings, rutas, ACL o VirtualBox.
- No usar `$Args` como nombre de variable: es una variable automática de PowerShell.
- Para activar/desactivar reglas usar `Enable-NetFirewallRule` y `Disable-NetFirewallRule`; no pasar un Boolean a `Set-NetFirewallRule -Enabled`, cuyo parámetro no debe tratarse como Boolean simple.
- No usar bloques `foreach` directamente como si fueran una salida de pipeline; asignar primero los resultados a una variable y luego procesarlos.
- Al interpolar variables seguidas de dos puntos, delimitar el nombre, por ejemplo `$($Name):` o `${Name}:` según el contexto.
- Al invocar `VBoxManage.exe` u otros ejecutables externos, comprobar `$LASTEXITCODE` inmediatamente después.
- No deshabilitar listeners, drivers o servicios del sistema basándose únicamente en un PID o número de puerto.
- No dar por probado un cambio porque el cmdlet no devolvió error: consultar el estado final, y cuando proceda contrastar PersistentStore y ActiveStore.
- Mantener los scripts de aplicación y de reversión completos, independientes y revisados; evitar instrucciones de parcheo parcial.
- Registrar la versión de Windows, build, edición, versión VirtualBox y fecha de la prueba.

## 7. Tareas que quedan pendientes

No se consideran completadas en esta fase:

1. **Cifrado de C: y D:** todavía no aplicado. Antes de hacerlo, preparar backup independiente, verificar soporte de la edición/dispositivo, comprobar recuperación y guardar las claves de recuperación fuera del equipo.
2. **ESU y actualizaciones:** verificar elegibilidad/inscripción, estado efectivo de ESU y la build de seguridad instalada. No asumir que instalar hardening equivale a estar actualizado.
3. **Migración a Windows 11:** pendiente. Los perfiles de Windows 10 no se reutilizan automáticamente.
4. **VPN dentro de Kali:** no se validó que el tráfico del invitado use una VPN instalada en el host. Si se requiere una ruta VPN propia de Kali, configurarla y comprobar desde el invitado IP pública, DNS y ruta efectiva.
5. **Nueva validación de integración VirtualBox:** repetir la inspección de carpetas compartidas, portapapeles, drag-and-drop, USB, 3D y `LocalhostReachable` después de actualizar/clonar/importar VM o VirtualBox.
6. **CFA en D:\Dev\GitHub:** no incluir la carpeta ni permitir `git.exe` globalmente sin evaluar antes el flujo de herramientas de desarrollo.

## 8. Regla de cierre de fase

Una fase se cierra solo cuando:

- existe una copia previa identificable;
- el cambio tiene alcance documentado;
- el valor final fue comprobado;
- se verificaron funciones esenciales del equipo;
- el rollback está disponible;
- las limitaciones residuales están escritas;
- se conserva un informe final fechado.

El informe final de Phase 8 del 13/11/2026 obtuvo 49 PASS, 0 REVIEW, 0 FAIL y 3 INFO. Ver [VALIDATION.md](./VALIDATION.md).
