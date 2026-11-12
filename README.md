# MyWindowsHardening

Colección de perfiles de hardening para Windows, separados por versión del sistema operativo y por objetivo de seguridad.

La idea del repositorio es evitar que un único script genérico mezcle controles, políticas y compatibilidades de Windows 10 y Windows 11.

## Organización

```text
MyWindowsHardening/
├── Win10/
│   ├── README.md
│   └── Network-Authentication/
│       ├── README.md
│       └── Outlook-NTLM-SMB-CVE-2026-124194/
│           ├── README.md
│           └── Windows-NTLM-SMB-Hardening.ps1
└── Win11/
    ├── README.md
    └── Network-Authentication/
        └── README.md
```

## Perfiles

| Plataforma | Dominio | Perfil | Estado |
|---|---|---|---|
| Windows 10 22H2 (19045) | Autenticación de red / protección de credenciales | Outlook, NTLM y SMB — CVE-2026-124194 | Primera implementación |
| Windows 11 | Autenticación de red | Reservado para una implementación y validación independientes | Pendiente |

## Cómo se organiza cada hardening

Cada perfil debe documentar explícitamente:

- **Objetivo:** qué amenaza o superficie de ataque aborda.
- **Alcance:** qué componentes y protocolos modifica.
- **No alcance:** qué protecciones no implementa.
- **Compatibilidad:** versiones y ediciones probadas, requisitos y limitaciones.
- **Auditoría:** cómo inspeccionar el estado antes de cambiarlo.
- **Aplicación:** qué modificaciones realiza y cuáles son opcionales.
- **Reversión:** cómo restaurar el estado previo.
- **Validación:** comandos y resultados que permiten comprobar el efecto.

## Reglas del repositorio

1. No reutilizar un script de Windows 10 en Windows 11 —ni a la inversa— sin verificar cmdlets, políticas, valores predeterminados y comportamiento.
2. Mantener los perfiles acotados: un hardening de NTLM/SMB no debe presentarse como hardening general del sistema.
3. Auditar antes de aplicar y conservar una copia de la configuración previa.
4. No bloquear puertos o servicios de forma indiscriminada para simular protección.
5. Los scripts complementan las actualizaciones del proveedor; no corrigen por sí solos las vulnerabilidades de las aplicaciones.

## Aviso

Los scripts modifican controles de seguridad del sistema. Deben ejecutarse con privilegios administrativos, revisarse antes de su uso y probarse en un entorno controlado. Las políticas de dominio, dispositivos NAS, servidores heredados y aplicaciones de terceros pueden cambiar el resultado.
