# MyWindowsHardening

Colección de perfiles de hardening para Windows, separados por versión del sistema operativo y por objetivo de seguridad.

La idea del repositorio es evitar que un único script genérico mezcle controles, políticas y compatibilidades de Windows 10, Windows 11 y Windows Server. Cada dominio debe tener alcance, requisitos, auditoría, aplicación, reversión y validación propios.

## Organización

~~~text
MyWindowsHardening/
├── AGENTS.md
├── CLAUDE.md
├── GEMINI.md
├── README.md
├── CONTRIBUTING.md
├── SECURITY.md
├── Common/
│   ├── README.md
│   └── Defender-Protection-Audit.ps1
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
├── WinServer/
│   ├── README.md
│   └── WinServer-Hardening-20261121.ps1
├── Tests/
│   ├── Repository.Safety.Tests.ps1
│   └── Knowledge.Safety.Tests.ps1
├── docs/
│   └── AI-AGENTS.md
├── .agents/
│   ├── rules/
│   └── skills/
├── .cursor/
│   └── rules/
├── .knowledge/
│   ├── index.md
│   ├── log.md
│   ├── decisions/
│   └── sources/
└── .github/
    ├── copilot-instructions.md
    ├── instructions/
    └── workflows/
        └── powershell-syntax-validation.yml
~~~

## Baselines generales

- [Windows 10 — auditoría](./Win10/Win10-Hardening-20261113.ps1).
- [Documentación baseline Windows 10](./Win10/BASELINE.md).
- [Windows 11 — auditoría](./Win11/Win11-Hardening-20261119.ps1), solo lectura.
- [Documentación y perfiles Windows 11](./Win11/README.md).
- [Windows Server — auditoría](./WinServer/WinServer-Hardening-20261121.ps1), solo lectura.
- [Documentación Windows Server](./WinServer/README.md).

## Perfiles

| Plataforma | Dominio | Perfil | Estado |
|---|---|---|---|
| [Windows 10 22H2 (19045)](./Win10/README.md) | [Autenticación de red](./Win10/Network-Authentication/README.md) | [Outlook, NTLM y SMB — CVE-2026-124194](./Win10/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md) | Primera implementación publicada |
| [Windows 10 22H2 (19045)](./Win10/README.md) | [Aislamiento de virtualización](./Win10/Virtualization-Isolation/README.md) | [VirtualBox — aislamiento de Kali](./Win10/Virtualization-Isolation/VirtualBox-Kali-Host-Isolation/README.md) | Configuración aplicada y validada en un equipo |
| [Windows 11](./Win11/README.md) | Autenticación de red | [Outlook / NTLM / SMB](./Win11/Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md) | Diseño y auditoría documentados; Apply/Restore pendiente |
| [Windows 11](./Win11/README.md) | Aislamiento de virtualización | [VirtualBox — Kali Host Isolation](./Win11/Virtualization-Isolation/VirtualBox-Kali-Host-Isolation/README.md) | Diseño documentado; validación práctica pendiente |
| [Windows Server](./WinServer/README.md) | Baseline empresarial | [Auditoría de roles y postura del servidor](./WinServer/WinServer-Hardening-20261121.ps1) | Auditoría inicial de solo lectura |

## Auditorías compartidas

El auditor [Defender-Protection-Audit.ps1](./Common/Defender-Protection-Audit.ps1) sirve para Windows 10 y Windows 11. Inspecciona las protecciones antivirus, ASR, Controlled Folder Access, Network Protection y exclusiones sin modificar la configuración. Los informes omiten los paths de exclusión y guardan únicamente sus cantidades. Ver [documentación](./Common/README.md).

## Instrucciones para agentes de IA

Este repositorio mantiene una sola fuente de reglas y conocimiento, compartida entre agentes y herramientas:

- **[AGENTS.md](./AGENTS.md)** — contrato canónico para agentes de programación: seguridad, arquitectura, flujos de trabajo y validación.
- **[docs/AI-AGENTS.md](./docs/AI-AGENTS.md)** — onboarding y compatibilidad de herramientas.
- **[.knowledge/index.md](./.knowledge/index.md)** — contexto del proyecto en Open Knowledge Format (OKF) v0.2, con fuentes, estado de vigencia y procedencia.
- **[.agents/skills/README.md](./.agents/skills/README.md)** — skills reutilizables para investigar Windows, diseñar cambios seguros, validar PowerShell y mantener el conocimiento.
- **[.agents/rules/](./.agents/rules/)** — reglas de Antigravity para seguridad, PowerShell y contexto.
- **[.cursor/rules/](./.cursor/rules/)** — reglas de Cursor Project Rules, usando archivos `.mdc`.
- **[.github/copilot-instructions.md](./.github/copilot-instructions.md)** y **[.github/instructions/](./.github/instructions/)** — instrucciones de Copilot generales y por tipo de archivo.
- **[CLAUDE.md](./CLAUDE.md)** y **[GEMINI.md](./GEMINI.md)** — archivos de entrada ligeros que derivan a las reglas canónicas.

Para agregar o modificar controles, seguir [CONTRIBUTING.md](./CONTRIBUTING.md). Las instrucciones específicas de agentes complementan, pero no pueden contradecir, `AGENTS.md`.

## Reglas del repositorio

1. No reutilizar un script de Windows 10 en Windows 11 —ni a la inversa— sin verificar cmdlets, políticas, valores predeterminados y comportamiento.
2. Mantener los perfiles acotados: NTLM/SMB no es hardening general, y aislamiento de VM no equivale a un sandbox absoluto.
3. Auditar antes de aplicar y conservar una copia de la configuración previa.
4. No bloquear puertos, servicios o reglas de firewall indiscriminadamente.
5. Distinguir entre estado observado, control aplicado, resultado validado y limitación conocida.
6. No publicar instaladores reutilizables hasta reconstruir, revisar, probar y dotar de reversión a los cambios.
7. Los scripts complementan las actualizaciones del proveedor; no corrigen por sí solos vulnerabilidades de aplicaciones.
8. Los perfiles generales Win10, Win11 y WinServer permanecen en modo de solo lectura hasta que cada control de aplicación tenga backup, rollback y pruebas propias.

## Calidad y validación

El workflow de PowerShell analiza los scripts de Common, Win10, Win11, WinServer y Tests con Windows PowerShell 5.1. Ejecuta PSScriptAnalyzer y las pruebas de seguridad de Pester. También valida los contratos básicos de documentación de agentes, skills y OKF. Los resultados de sintaxis y tests estáticos no sustituyen pruebas funcionales en equipos Windows reales.

## Aviso

Los scripts que modifiquen controles de seguridad deben ejecutarse con privilegios administrativos, revisarse y probarse en un entorno controlado. Las políticas de dominio, dispositivos NAS, servidores heredados, VPN, hipervisores y aplicaciones de terceros pueden cambiar el resultado.
