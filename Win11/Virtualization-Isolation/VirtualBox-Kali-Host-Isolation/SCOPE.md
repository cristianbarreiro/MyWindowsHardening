# Scope — Windows 11 / VirtualBox Kali Host Isolation

## Objetivo
Reducir canales de comunicación no necesarios entre Kali Linux y el host Windows 11, conservando NAT cuando la VM necesita conectividad saliente.

## Incluido
- Inventario de plataforma Windows 11 y estado VBS/Hyper-V.
- Inventario de redes VirtualBox y adaptadores de cada VM.
- Evaluación de Shared Folders, Clipboard, Drag and Drop, USB y 3D.
- Revisión de firewall, servicios y bindings relacionados.
- Validación desde host e invitado.
- Registro de backup, cambios y rollback para cada control futuro.

## Excluido
- Deshabilitar globalmente Hyper-V, VBS, HVCI, Credential Guard, TPM o Secure Boot.
- Deshabilitar servicios Windows por lotes.
- Bloquear todas las conexiones salientes del invitado.
- Prometer aislamiento completo de LAN usando NAT.
- Configurar VPN, anonimato o evasión de detección.
- Publicar scripts de aplicación antes de validar versiones de Windows 11 y VirtualBox.

## Riesgos residuales
- Vulnerabilidades de escape del hipervisor.
- Rutas de red salientes desde el invitado.
- Exposición voluntaria de datos mediante archivos o credenciales copiadas.
- Integraciones que se vuelvan a habilitar en la VM.
- Cambios de comportamiento entre versiones de VirtualBox y Windows.

## Criterio para automatización futura
Cada cambio deberá tener detección previa, backup, comprobación de compatibilidad, aplicación idempotente, rollback específico y evidencia. Si no puede restaurarse el estado anterior con precisión, el control no debe automatizarse.
