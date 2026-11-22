# Operations — Windows 11 / VirtualBox Kali Host Isolation

## Antes de cambiar la configuración
1. Exportar la configuración de la VM con VBoxManage y guardar el resultado fuera de la carpeta de la VM.
2. Crear un snapshot consistente de Kali.
3. Registrar adaptadores, rutas, DNS, reglas de firewall y servicios.
4. Registrar VBS, HVCI, Credential Guard y Hyper-V.
5. Asegurar acceso local al host; no depender exclusivamente de administración remota para cambios de firewall.

## Aplicación manual
Los cambios se realizan individualmente desde VirtualBox o mediante VBoxManage después de revisar el valor actual. No existe un script Apply publicado para este perfil.

No ejecutar bloques de deshabilitación masiva de servicios ni comandos que apaguen Hyper-V/VBS como solución genérica.

## Reversión
- Restaurar cada ajuste de VM desde la exportación o snapshot cuando corresponda.
- Restaurar únicamente reglas de firewall creadas por el procedimiento; no borrar reglas preexistentes.
- Restaurar servicios solo a los valores registrados antes del cambio.
- No cambiar VBS/Hyper-V/Memory Integrity a ciegas: seguir el registro previo y las políticas de la organización.
- Reiniciar y repetir la matriz de validación.

## Incidentes
Si Kali pierde conectividad, revisar primero modo de adaptador, NAT, DNS y rutas del invitado. Si VirtualBox pierde rendimiento o no inicia, revisar compatibilidad con el hipervisor de Windows antes de deshabilitar controles de seguridad.
