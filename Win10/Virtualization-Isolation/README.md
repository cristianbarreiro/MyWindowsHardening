# Windows 10 — Virtualization Isolation

Perfiles para reducir la superficie de comunicación entre máquinas virtuales y el sistema anfitrión Windows 10.

Esta categoría no pretende convertir VirtualBox en un sandbox infalible ni sustituir las actualizaciones del hipervisor y del sistema operativo. Cada perfil debe describir la topología real de red, las integraciones habilitadas entre invitado y host, los servicios expuestos, las reglas de firewall y los caminos de salida a otras redes.

## Perfil documentado

- [VirtualBox — Kali Host Isolation](./VirtualBox-Kali-Host-Isolation/README.md)

## Criterios de esta categoría

1. Preferir NAT frente a Bridged cuando la VM solo necesita conectividad saliente.
2. No mantener adaptadores Host-Only o Bridged innecesarios.
3. Deshabilitar carpetas compartidas, portapapeles, arrastrar y soltar, USB y aceleración 3D cuando no sean necesarios para el caso de uso.
4. Limitar los servicios de Windows que aceptan conexiones entrantes y preservar los que necesita el host.
5. No confundir aislamiento de conexiones entrantes al host con aislamiento total de la LAN: NAT permite tráfico saliente y no constituye un air gap.
6. Conservar copias de la configuración de firewall, VirtualBox, servicios, bindings y ACL antes de cada cambio.
7. Validar desde el host y desde el invitado. La configuración del host, por sí sola, no demuestra qué rutas o DNS utiliza realmente el invitado.

## Compatibilidad

El perfil disponible está documentado para Windows 10 22H2 (build 19045) y VirtualBox 7.2.22. No se debe aplicar automáticamente en Windows 11, otras ediciones, otras versiones del hipervisor o equipos con otra topología de red.
