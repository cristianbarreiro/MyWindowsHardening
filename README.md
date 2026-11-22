# MyWindowsHardening

Colección de perfiles de hardening para Windows, separados por versión del sistema operativo y por objetivo de seguridad.

La idea del repositorio es evitar que un único script genérico mezcle controles, políticas y compatibilidades de Windows 10, Windows 11 y Windows Server. Cada dominio debe tener alcance, requisitos, auditoría, aplicación, reversión y validación propios.

## Organización

~~~text
MyWindowsHardening/
├── README.md
├── Win10/
│   ├── README.md
│   ├── Win10-Hardening-20261113.ps1
│   ├── BASELINE.md
│   ├── Network-Authentication/
│   └── Virtualization-Isolation/
├── Win11/
│   ├── README.md
│   ├── Win11-Hardening-20261119.ps1
│   ├── Network-Authentication/
│   └── Virtualization-Isolation/
└── WinServer/
    └── WinServer-Hardening-20261121.ps1
~~~

## Baselines generales
- [Windows 10 — auditoría](./Win10/Win10-Hardening-20261113.ps1).
- [Documentación baseline Windows 10](./Win10/BASELINE.md).
- [Windows 11 — auditoría](./Win11/Win11-Hardening-20261119.ps1), solo lectura.
- [Documentación y perfiles Windows 11](./Win11/README.md).

## Perfiles

| Plataforma | Dominio | Perfil | Estado |
|---|---|---|---|
| [Windows 10 22H2 (19045)](./Win10/README.md) | [Autenticación de red](./Win10/Network-Authentication/README.md) | [Outlook, NTLM y SMB — CVE-2026-124194](./Win10/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md) | Primera implementación publicada |
| [Windows 10 22H2 (19045)](./Win10/README.md) | [Aislamiento de virtualización](./Win10/Virtualization-Isolation/README.md) | [VirtualBox — aislamiento de Kali](./Win10/Virtualization-Isolation/VirtualBox-Kali-Host-Isolation/README.md) | Configuración aplicada y validada en un equipo |
| [Windows 11](./Win11/README.md) | Autenticación de red | [Outlook / NTLM / SMB](./Win11/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md) | Diseño y auditoría documentados; Apply/Restore pendiente |
| [Windows 11](./Win11/README.md) | Aislamiento de virtualización | [VirtualBox — Kali Host Isolation](./Win11/Virtualization-Isolation/VirtualBox-Kali-Host-Isolation/README.md) | Diseño documentado; validación práctica pendiente |

## Reglas del repositorio
1. No reutilizar un script de Windows 10 en Windows 11 —ni a la inversa— sin verificar cmdlets, políticas, valores predeterminados y comportamiento.
2. Mantener los perfiles acotados: NTLM/SMB no es hardening general, y aislamiento de VM no equivale a un sandbox absoluto.
3. Auditar antes de aplicar y conservar una copia de la configuración previa.
4. No bloquear puertos, servicios o reglas de firewall indiscriminadamente.
5. Distinguir entre estado observado, control aplicado, resultado validado y limitación conocida.
6. No publicar instaladores reutilizables hasta reconstruir, revisar, probar y dotar de reversión a los cambios.
7. Los scripts complementan las actualizaciones del proveedor; no corrigen por sí solos vulnerabilidades de aplicaciones.

## Aviso
Los scripts que modifiquen controles de seguridad deben ejecutarse con privilegios administrativos, revisarse y probarse en un entorno controlado. Las políticas de dominio, dispositivos NAS, servidores heredados, VPN, hipervisores y aplicaciones de terceros pueden cambiar el resultado.
