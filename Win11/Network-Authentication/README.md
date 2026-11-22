# Windows 11 — Network Authentication

Perfiles para reducir la exposición de credenciales durante autenticaciones de red en Windows 11 cliente.

## Perfil
- [Outlook / NTLM / SMB — protección de credenciales](./Outlook-NTLM-SMB-CVE-2026-124194/README.md)

## Alcance
- SMB Client Signing y SMB Server Signing.
- Auditoría de NTLM saliente y canal NTLM Operational.
- Restricciones de SMB/NetBIOS saliente hacia redes no confiables.
- Bloqueo de NTLM sobre SMB solo cuando la plataforma exponga el control soportado.
- Servicio WebClient/WebDAV como opción separada y dependiente del uso.

## Límites
- No se bloquea NTLM globalmente por defecto.
- No se fuerza SMB Server Signing sin evaluar shares, NAS, impresoras y compatibilidad.
- No se crean reglas de firewall amplias ni se bloquean TCP 80/443.
- No se asume que un cmdlet de Windows 10 tenga idéntico soporte en todas las builds de Windows 11.
- No se sustituyen los parches de Office/Outlook ni las actualizaciones de Windows.

## Estado
Documentación de diseño para Windows 11. La automatización Apply/Restore queda pendiente de validación por build y edición; no reutilizar el script Win10. La auditoría de referencia es [Win11-Hardening-20261119.ps1](../Win11-Hardening-20261119.ps1), estrictamente de solo lectura.
