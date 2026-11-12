# Windows 10

Esta carpeta contiene perfiles diseñados y comprobados específicamente para Windows 10. No se deben asumir equivalencias con Windows 11.

## Plataforma inicial

- **Versión objetivo:** Windows 10 22H2.
- **Build base:** 19045.
- **Entorno de primera validación:** Windows 10 Home Single Language, 22H2, build 19045.6466 (12/11/2026).

La validación anterior representa un único equipo y no certifica automáticamente todas las ediciones, políticas de dominio o configuraciones de Windows 10.

## Estado de soporte y actualizaciones

Windows 10 22H2 terminó su soporte ordinario el 14/10/2025. Los equipos que continúen en Windows 10 deben comprobar su elegibilidad e inscripción en el programa ESU y mantener instaladas las actualizaciones disponibles. El hardening de este repositorio no sustituye esas actualizaciones.

En la información de versión de Microsoft consultada el 26/10/2026 figura la build 19045.7811 como actualización ESU de Windows 10 22H2. El equipo usado para la primera validación, build 19045.6466, estaba por debajo de esa referencia; comprobá Windows Update/ESU antes de considerar el sistema actualizado.

Referencias:
- [Windows 10 — información de versión y ESU](https://learn.microsoft.com/es-es/windows/release-health/release-information)
- [Ciclo de vida de Windows 10 Home y Pro](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro)

## Perfiles disponibles

| Carpeta | Objetivo |
|---|---|
| [Network-Authentication](./Network-Authentication/README.md) | Controles de autenticación de red, SMB y exposición de credenciales. |

## Convenciones

Cada perfil de esta carpeta debe especificar la versión/build admitida y rechazar la ejecución si el equipo no pertenece al ámbito previsto, cuando sea técnicamente posible.
