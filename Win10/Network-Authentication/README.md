# Windows 10 — Network Authentication

Perfiles que reducen la exposición de credenciales durante autenticaciones de red. Esta categoría no es un paquete genérico de hardening de Windows.

## Perfil disponible

- [Outlook / NTLM / SMB — CVE-2026-124194](./Outlook-NTLM-SMB-CVE-2026-124194/README.md)

## Qué cubre esta categoría

Según cada perfil, puede incluir controles sobre SMB/NetBIOS saliente, firma SMB, auditoría de NTLM y servicios de acceso a archivos como WebClient/WebDAV.

## Qué no debe asumirse

- No implica bloquear NTLM globalmente.
- No sustituye Kerberos ni migra aplicaciones heredadas.
- No configura automáticamente Active Directory, GPO, EPA o Protected Users.
- No equivale a una configuración completa de Microsoft Defender, ASR o firewall.
- No corrige vulnerabilidades de Outlook u otras aplicaciones: primero se aplican los parches del proveedor.

Cada perfil detalla por separado los controles que sí aplica y los que quedan fuera de alcance.
