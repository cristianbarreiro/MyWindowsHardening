# Windows 10

Esta carpeta contiene perfiles diseñados y comprobados específicamente para Windows 10. No se deben asumir equivalencias con Windows 11.

## Plataforma inicial

- **Versión objetivo:** Windows 10 22H2.
- **Build base:** 19045.
- **Entorno de primera validación:** Windows 10 Home Single Language, 22H2, build 19045.6466 (12/11/2026).

Las evidencias de los perfiles representan un único equipo y no certifican automáticamente todas las ediciones, políticas de dominio o configuraciones de Windows 10.

## Estado de soporte y actualizaciones

Windows 10 22H2 terminó su soporte ordinario el 14/10/2025. Los equipos que continúen en Windows 10 deben comprobar su elegibilidad e inscripción en el programa ESU y mantener instaladas las actualizaciones disponibles. El hardening de este repositorio no sustituye esas actualizaciones.

Según el historial de versiones de Microsoft consultado el 23/11/2026, la actualización más reciente publicada para Windows 10 22H2 es la 2026-11 OOB del 13/11/2026: build **19045.7850 (KB5136493)**. Esta referencia no significa que todos los equipos puedan recibirla: las actualizaciones ESU requieren elegibilidad e inscripción aplicable. Verificá Windows Update, el estado de ESU y la edición/canal del equipo. El equipo usado para la primera validación, build 19045.6466, está por debajo de esa referencia histórica; no debe considerarse actualizado por aquella prueba.

Referencias:
- [Windows 10 — información de versión y ESU](https://learn.microsoft.com/es-es/windows/release-health/release-information)
- [Ciclo de vida de Windows 10 Home y Pro](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro)

## Baseline general reutilizable

- [Win10-Hardening-20261113.ps1](./Win10-Hardening-20261113.ps1) — núcleo de auditoría de solo lectura v0.1.1.
- [BASELINE.md](./BASELINE.md) — arquitectura, modos, límites y hoja de ruta.

El baseline general no sustituye los perfiles especializados ni los ejecuta automáticamente. Su función es inventariar y producir informes sin cambiar la configuración del equipo. Los informes contienen datos del dispositivo, adaptadores y postura de seguridad; protegé los archivos y sanealos antes de compartirlos.

## Auditoría Microsoft Defender\n\nTambién se puede ejecutar el auditor compartido de Windows 10/11: [Defender-Protection-Audit.ps1](../Common/Defender-Protection-Audit.ps1). Es estrictamente de solo lectura e inventaría antivirus, ASR, Controlled Folder Access, Network Protection y exclusiones. No aplica ni modifica reglas. Consultá [su documentación](../Common/README.md).\n\n## Perfiles disponibles

| Dominio | Carpeta / perfil | Objetivo |
|---|---|---|
| [Network-Authentication](./Network-Authentication/README.md) | [Outlook / NTLM / SMB — CVE-2026-124194](./Network-Authentication/Outlook-NTLM-SMB-CVE-2026-124194/README.md) | Reducir determinadas rutas de exposición de autenticación de red y habilitar auditoría NTLM. |
| [Virtualization-Isolation](./Virtualization-Isolation/README.md) | [VirtualBox / Kali Host Isolation](./Virtualization-Isolation/VirtualBox-Kali-Host-Isolation/README.md) | Reducir la superficie de comunicación entre una VM Kali Linux y el host Windows, preservando la conectividad NAT y las herramientas de desarrollo. |

## Convenciones

Cada perfil de esta carpeta debe especificar la versión/build admitida y rechazar la ejecución si el equipo no pertenece al ámbito previsto, cuando sea técnicamente posible.

Los perfiles de aislamiento de VM deben documentar por separado la topología virtual, las interfaces conectadas, las integraciones Guest↔Host, las reglas de firewall, los servicios del host, la conectividad de salida y los riesgos que NAT no elimina.
