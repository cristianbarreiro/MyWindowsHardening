# MyWindowsHardening

Colección de perfiles de hardening para Windows, separados por versión del sistema operativo y por objetivo de seguridad.

La idea del repositorio es evitar que un único script genérico mezcle controles, políticas y compatibilidades de Windows 10 y Windows 11. Cada dominio debe tener alcance, requisitos, auditoría, aplicación, reversión y validación propios.

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
└── Win11/
    ├── README.md
    └── Win11-Hardening-20261119.ps1
~~~

## Baselines generales

- [Windows 10 — Win10-Hardening-20261113.ps1](./Win10/Win10-Hardening-20261113.ps1) — núcleo reutilizable v0.1.0, actualmente de solo lectura.
- [Documentación del baseline Windows 10](./Win10/BASELINE.md).
- [Windows 11 — Win11-Hardening-20261119.ps1](./Win11/Win11-Hardening-20261119.ps1) — auditor de solo lectura v0.1.0, diseñado para Windows 11 cliente (build 22000+).
- [Documentación del baseline Windows 11](./Win11/README.md).

## Perfiles

| Plataforma | Dominio | Perfil | Estado |
|---|---|---|---|
| [Windows 10 22H2 (19045)](./Win10/README.md) | [Autenticación de red](./Win10/Network-Authentication/README.md) | [Outlook, NTLM y SMB — CVE-2026-124194](./Win10/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md) | Primera implementación publicada |
| [Windows 10 22H2 (19045)](./Win10/README.md) | [Aislamiento de virtualización](./Win10/Virtualization-Isolation/README.md) | [VirtualBox — aislamiento de Kali respecto del host](./Win10/Virtualization-Isolation/VirtualBox-Kali-Host-Isolation/README.md) | Configuración aplicada y validada en un único equipo; documentación técnica |
| [Windows 11](./Win11/README.md) | Baseline general | [Auditoría Windows 11](./Win11/Win11-Hardening-20261119.ps1) | v0.1.0 — solo lectura |
| [Windows 11](./Win11/README.md) | Autenticación de red | [Network-Authentication](./Win11/Network-Authentication/README.md) | Pendiente |

## Cómo se organiza cada hardening

Cada perfil debe documentar explícitamente:

- **Objetivo:** qué amenaza o superficie de ataque aborda.
- **Alcance y no alcance:** qué componentes modifica y qué protecciones no implementa.
- **Compatibilidad:** versiones, ediciones y requisitos probados.
- **Auditoría:** cómo inspeccionar el estado antes de cambiarlo.
- **Aplicación:** qué modificaciones realiza y cuáles son opcionales.
- **Reversión:** cómo restaurar el estado previo.
- **Validación:** comandos, evidencias y resultados que permiten comprobar el efecto.
- **Limitaciones:** riesgos residuales, falsos supuestos y dependencias que deben preservarse.

## Reglas del repositorio

1. No reutilizar un script de Windows 10 en Windows 11 —ni a la inversa— sin verificar cmdlets, políticas, valores predeterminados y comportamiento.
2. Mantener los perfiles acotados: un hardening de NTLM/SMB no debe presentarse como hardening general del sistema, y un perfil de aislamiento de VM no debe prometer un sandbox absoluto.
3. Auditar antes de aplicar y conservar una copia de la configuración previa.
4. No bloquear puertos, servicios o reglas de firewall de forma indiscriminada para simular protección.
5. Distinguir entre **estado observado**, **control aplicado**, **resultado validado** y **limitación conocida**.
6. No publicar como instalador reutilizable un conjunto de cambios manuales o scripts de una sesión si no se han reconstruido, revisado, probado y dotado de reversión.
7. Los scripts complementan las actualizaciones del proveedor; no corrigen por sí solos las vulnerabilidades de las aplicaciones.

## Aviso

Los scripts modifican controles de seguridad del sistema. Deben ejecutarse con privilegios administrativos, revisarse antes de su uso y probarse en un entorno controlado. Las políticas de dominio, dispositivos NAS, servidores heredados, VPN, hipervisores y aplicaciones de terceros pueden cambiar el resultado.
