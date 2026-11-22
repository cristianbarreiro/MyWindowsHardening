# Validation Plan — Windows 11 / VirtualBox Kali Host Isolation

**Estado:** plan pendiente. No hay resultados de ejecución Windows 11 asociados a este perfil.

## Host
- [ ] Registrar Windows 11 edition, DisplayVersion, build y UBR.
- [ ] Registrar VirtualBox y Extension Pack version.
- [ ] Registrar Secure Boot, TPM, VBS, HVCI y Credential Guard.
- [ ] Registrar firewall profiles y ActiveStore rules.
- [ ] Registrar adaptadores físicos, virtuales y ocultos.
- [ ] Registrar servicios y dependencias relevantes.
- [ ] Crear snapshot de VM y backup de configuración antes de cambios.

## VirtualBox
- [ ] Confirmar NAT en el adaptador requerido.
- [ ] Confirmar adaptadores adicionales desconectados si no son necesarios.
- [ ] Revisar NAT port forwarding.
- [ ] Confirmar Shared Folders deshabilitadas si no se necesitan.
- [ ] Confirmar Shared Clipboard y Drag and Drop deshabilitados.
- [ ] Revisar USB passthrough, webcam/audio y aceleración 3D.
- [ ] Confirmar que no se modificó la configuración de otras VMs.

## Invitado Kali
- [ ] Revisar interfaces, rutas y DNS.
- [ ] Confirmar conectividad saliente esperada.
- [ ] Confirmar ausencia de interfaces Bridged/Host-Only inesperadas.
- [ ] Probar acceso a servicios del host que deberían permanecer inaccesibles.
- [ ] Confirmar que no hay rutas alternativas hacia la LAN no contempladas.

## Seguridad y regresión
- [ ] Confirmar que VBS/HVCI/Credential Guard permanecen en el estado decidido.
- [ ] Confirmar Windows Update, Defender y Firewall operativos.
- [ ] Confirmar que WSL2/Hyper-V y otras VMs no se rompieron.
- [ ] Confirmar Wi-Fi, impresión, VPN, DNS y recursos compartidos requeridos.
- [ ] Reiniciar host y VM; repetir pruebas.
- [ ] Restaurar backup en un ensayo y comparar el estado resultante.

## Evidencia
Adjuntar comandos, salidas sanitizadas, fecha, build, versión VirtualBox y resultado PASS/FAIL/NOT TESTED. No marcar una prueba como PASS por inferencia.
