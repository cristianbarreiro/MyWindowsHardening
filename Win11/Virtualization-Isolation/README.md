# Windows 11 — Virtualization Isolation

Perfiles para reducir la superficie de comunicación entre máquinas virtuales y el host Windows 11.

## Perfil documentado
- [VirtualBox — Kali Host Isolation](./VirtualBox-Kali-Host-Isolation/README.md)

## Principios
1. Preferir NAT cuando la VM necesita conectividad saliente y no necesita ser accesible directamente desde la LAN.
2. Desconectar adaptadores Host-Only y Bridged innecesarios.
3. Deshabilitar carpetas compartidas, portapapeles, drag-and-drop, USB passthrough y aceleración 3D cuando no se necesiten.
4. Mantener Windows Defender Firewall habilitado y revisar reglas efectivas.
5. No deshabilitar indiscriminadamente Hyper-V, VBS, Memory Integrity, Credential Guard, WSL2 o Windows Hypervisor Platform.
6. Conservar backups de VirtualBox, firewall, bindings y servicios antes de cambios.
7. Validar rutas, DNS y conectividad desde host e invitado.

## Compatibilidad
El perfil requiere Windows 11 cliente y una versión de VirtualBox identificada en la validación. Las interacciones con Hyper-V, VBS, Memory Integrity, WSL2 y Windows Hypervisor Platform dependen de build, hardware y configuración.

## Estado
Documentación de diseño adaptada a Windows 11. No se publica un script de aplicación automática: la topología y el estado de seguridad del hipervisor deben auditarse en cada equipo antes de cambiar reglas o servicios.
