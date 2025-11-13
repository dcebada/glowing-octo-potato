# lemarchand – NixOS Workstation

**CPU:** AMD Ryzen 9 6900HX | **GPU:** AMD Radeon RX 680M | **SSD:** Samsung NVMe (PCIe 4.0)

## Características

- ✅ **Cifrado completo LUKS 2** con desbloqueo mediante Google Titan U2F
- ✅ **Limine bootloader** (ligero y compatible con LUKS 2)
- ✅ **Btrfs optimizado** (compress-zstd, ssd_spread, snapshots automáticos)
- ✅ **Entorno Omarchy** (Hyprland + Waybar + Mako + Swww)
- ✅ **Wallpapers dinámicos** (cambio por hora del día o aleatorio)
- ✅ **Terminal Ghostty** (Victor Mono Nerd Italic)
- ✅ **Gestor de versiones mise** (rtx)
- ✅ **Herramientas modernas** (eza, bat, fd, ripgrep, fzf, zoxide)
- ✅ **Steam + Steam Controller** listos para usar
- ✅ **Login y sudo protegidos** por la misma llave U2F

---

## 📋 Requisitos Previos

1. **USB de instalación de NixOS** (última versión estable)
2. **Google Titan Security Key** (o cualquier llave U2F compatible)
3. **Acceso a Internet** durante la instalación
4. **Backup de datos** (la instalación formateará el disco)

---

## 🚀 Instalación Paso a Paso

### 1. Preparar el Entorno de Instalación

Arranca desde el USB de NixOS y ejecuta:

```bash
# Activar WiFi (si es necesario)
sudo systemctl start wpa_supplicant
wpa_cli

# O usar nmtui para configuración gráfica
nmtui
```

### 2. Particionar el Disco

**IMPORTANTE:** Ajusta `/dev/nvme0n1` según tu hardware. Verifica con `lsblk`.

```bash
# Verificar el disco
lsblk

# Particionar (ejemplo para NVMe)
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart primary 512MiB 100%

# Formatear partición EFI
sudo mkfs.fat -F 32 -n EFI /dev/nvme0n1p1

# Obtener UUID de la partición EFI
sudo blkid /dev/nvme0n1p1
# Anota el UUID (lo necesitarás después)
```

### 3. Crear Volumen LUKS 2

```bash
# Crear contenedor LUKS 2
sudo cryptsetup luksFormat --type luks2 /dev/nvme0n1p2

# Abrir el contenedor
sudo cryptsetup open /dev/nvme0n1p2 cryptroot

# Obtener UUID del dispositivo LUKS
sudo blkid /dev/nvme0n1p2
# Anota el UUID (lo necesitarás después)
```

### 4. Configurar Btrfs con Subvolúmenes

```bash
# Formatear el volumen descifrado con Btrfs
sudo mkfs.btrfs -L root /dev/mapper/cryptroot

# Montar temporalmente
sudo mount /dev/mapper/cryptroot /mnt

# Crear subvolúmenes
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@var-log
sudo btrfs subvolume create /mnt/@snapshots

# Desmontar
sudo umount /mnt
```

### 5. Montar el Sistema de Archivos

```bash
# Montar subvolúmenes
sudo mount -o subvol=@,compress=zstd,ssd_spread,noatime,space_cache=v2 /dev/mapper/cryptroot /mnt
sudo mkdir -p /mnt/{boot/efi,home,nix,var/log,.snapshots}

sudo mount -o subvol=@home,compress=zstd,ssd_spread,noatime,space_cache=v2 /dev/mapper/cryptroot /mnt/home
sudo mount -o subvol=@nix,compress=zstd,ssd_spread,noatime,space_cache=v2 /dev/mapper/cryptroot /mnt/nix
sudo mount -o subvol=@var-log,compress=zstd,ssd_spread,noatime,space_cache=v2 /dev/mapper/cryptroot /mnt/var/log
sudo mount -o subvol=@snapshots,compress=zstd,ssd_spread,noatime,space_cache=v2 /dev/mapper/cryptroot /mnt/.snapshots

# Montar partición EFI (reemplaza UUID-EFI con el UUID real)
sudo mount /dev/disk/by-uuid/UUID-EFI /mnt/boot/efi
```

### 6. Clonar el Repositorio

```bash
# Instalar git si no está disponible
nix-env -iA nixos.git

# Clonar el repositorio
cd /mnt
sudo git clone https://github.com/tu-usuario/glowing-octo-potato.git
cd glowing-octo-potato/lemarchand
```

### 7. Configurar UUIDs

Los UUIDs ahora se configuran como parámetros del flake. Tienes dos opciones:

**Opción A: Variables de entorno (Recomendado)**

```bash
# Obtener UUIDs
LUKS_UUID=$(sudo blkid -s UUID -o value /dev/nvme0n1p2)
EFI_UUID=$(sudo blkid -s UUID -o value /dev/nvme0n1p1)

# Exportar variables
export LUKS_UUID
export EFI_UUID

# Verificar
echo "LUKS UUID: $LUKS_UUID"
echo "EFI UUID: $EFI_UUID"
```

**Opción B: Editar flake.nix directamente**

Edita `flake.nix` y cambia los valores por defecto en las líneas 33-34:

```nix
luksUuid = if luksUuidEnv != "" then luksUuidEnv else "TU-UUID-LUKS-AQUI";
efiUuid = if efiUuidEnv != "" then efiUuidEnv else "TU-UUID-EFI-AQUI";
```

Reemplaza `REPLACE-WITH-LUKS-UUID` y `REPLACE-WITH-EFI-UUID` con tus UUIDs reales.

**Método C: Usar archivo .env**

```bash
# Crear archivo .env
cat > .env << EOF
LUKS_UUID=tu-uuid-luks-aqui
EFI_UUID=tu-uuid-efi-aqui
EOF

# Cargar variables
source .env

# Instalar
sudo nixos-install --flake .#lemarchand --root /mnt
```

**Verificación de UUIDs:**

```bash
# Ver la configuración evaluada
sudo nixos-rebuild switch --flake .#lemarchand --dry-run

# O verificar en el sistema
cat /etc/nixos/configuration.nix | grep -A 2 "luks.devices"
```

**Notas sobre UUIDs:**
- Los valores por defecto son `REPLACE-WITH-LUKS-UUID` y `REPLACE-WITH-EFI-UUID` si no se configuran las variables de entorno
- Las variables de entorno tienen prioridad sobre los valores por defecto en `flake.nix`
- Asegúrate de que los UUIDs sean correctos antes de instalar, o el sistema no arrancará

### 8. Generar `hardware-configuration.nix`

```bash
# Generar configuración de hardware
sudo nixos-generate-config --root /mnt

# Copiar la configuración generada
sudo cp /mnt/etc/nixos/hardware-configuration.nix nixos/hardware-configuration.nix
```

### 9. Instalar NixOS

```bash
# Construir e instalar el sistema
sudo nixos-install --flake .#lemarchand --root /mnt

# Durante la instalación, se te pedirá:
# - Contraseña para el usuario root
# - Contraseña para el usuario daniel
```

### 10. Configurar U2F para Desbloqueo del Disco

**IMPORTANTE:** Esto debe hacerse DESPUÉS de la primera instalación y reinicio.

```bash
# Reiniciar y entrar al sistema
sudo reboot

# Una vez dentro del sistema, registrar la llave U2F para LUKS
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2

# Verificar que se registró correctamente
sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2 --list
```

**Nota:** Asegúrate de mantener una contraseña de respaldo. Si pierdes la llave U2F, necesitarás la contraseña para acceder.

### 11. Configurar U2F para Login y Sudo

```bash
# Instalar herramientas U2F (ya deberían estar instaladas)
# Registrar tu llave U2F para PAM
pamu2fcfg -u daniel > ~/.config/Yubico/u2f_keys

# Copiar al sistema (requiere permisos root)
sudo mkdir -p /etc/u2f_mappings
sudo cp ~/.config/Yubico/u2f_keys /etc/u2f_mappings/daniel

# Verificar que funciona
sudo -v  # Debería pedirte que toques la llave U2F
```

### 12. Instalar Limine (Opcional)

Si prefieres usar Limine en lugar de systemd-boot:

```bash
# Instalar Limine
nix-env -iA nixos.limine

# Copiar Limine a la partición EFI
sudo cp /nix/store/*limine*/share/limine/limine.sys /boot/efi/EFI/limine/
sudo cp /nix/store/*limine*/share/limine/limine.cfg /boot/efi/EFI/limine/

# Crear entrada EFI para Limine
sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Limine" -l "\EFI\limine\limine.sys"
```

**Nota:** La configuración de Limine con LUKS requiere ajustes manuales en `limine.cfg`. Consulta la [documentación de Limine](https://github.com/limine-bootloader/limine) para más detalles.

### 13. Configurar Wallpapers Dinámicos

El sistema incluye soporte para wallpapers dinámicos que cambian según la hora del día o de forma aleatoria.

**Estructura de archivos:**

Coloca tus wallpapers en `$XDG_CONFIG_HOME/swww/wallpapers/` (por defecto `~/.config/swww/wallpapers/`):

- `morning.jpg` - Para mañana (06:00 - 11:59)
- `afternoon.jpg` - Para mediodía (12:00 - 16:59)
- `evening.jpg` - Para tarde (17:00 - 19:59)
- `night.jpg` - Para noche (20:00 - 05:59)
- `default.jpg` - Fallback si falta alguno de los anteriores

**Formato de archivos:**
- Formatos soportados: `.jpg`, `.png`, `.jpeg`
- Resolución recomendada: igual o mayor a la resolución de tu monitor principal
- Para múltiples monitores: el wallpaper se aplicará a todos

**Modo aleatorio:**

Cualquier archivo `.jpg`, `.png` o `.jpeg` en la carpeta se puede seleccionar aleatoriamente.

**Uso:**

```bash
# Cambiar a modo aleatorio
$XDG_CONFIG_HOME/swww/wallpaper-dynamic.sh random

# Cambiar a modo por hora
$XDG_CONFIG_HOME/swww/wallpaper-dynamic.sh time

# Establecer un wallpaper específico
$XDG_CONFIG_HOME/swww/wallpaper-dynamic.sh set $XDG_CONFIG_HOME/swww/wallpapers/mi-wallpaper.jpg
```

**Configuración:**

Edita `$XDG_CONFIG_HOME/swww/wallpaper-config` para cambiar el modo por defecto:
- `MODE="time"` - Cambia según hora del día (por defecto)
- `MODE="random"` - Selección aleatoria

**Atajos de teclado en Hyprland:**
- `Super + W` - Cambiar a modo aleatorio
- `Super + Shift + W` - Cambiar a modo por hora

**Nota:** El sistema cambia automáticamente el wallpaper cada hora cuando está en modo `time`.

### 14. Reiniciar

```bash
sudo reboot
```

Al arrancar, deberías poder:
1. Desbloquear el disco con tu llave U2F (o contraseña de respaldo)
2. Iniciar sesión con tu llave U2F
3. Usar `sudo` con tu llave U2F

---

## 🔧 Post-Instalación

### Snapshots Automáticos de Btrfs

Los snapshots se pueden crear manualmente o configurar con `snapper` o `btrbk`:

```bash
# Crear snapshot manual
sudo btrfs subvolume snapshot -r / /.snapshots/$(date +%Y%m%d-%H%M%S)

# Listar snapshots
sudo btrfs subvolume list /

# Restaurar desde snapshot
sudo btrfs subvolume delete /path/to/bad/subvolume
sudo btrfs subvolume snapshot /.snapshots/YYYYMMDD-HHMMSS /path/to/restored
```

### Personalizar Hyprland

Edita `~/.config/hypr/hyprland.conf` para ajustar:
- Atajos de teclado
- Monitores
- Efectos visuales
- Aplicaciones al inicio

### Gestor de Versiones mise

```bash
# mise ya está instalado y configurado en fish
# Usar mise para instalar versiones de herramientas
mise install node@20 python@3.11

# Ver herramientas disponibles
mise ls
```

### Herramientas de Desarrollo Modernas

El sistema incluye herramientas modernas inspiradas en Omarchy:

**Herramientas de línea de comandos:**
- `eza` - `ls` moderno con iconos y colores
- `bat` - `cat` con syntax highlighting
- `fd` - `find` rápido y simple
- `ripgrep` (rg) - `grep` ultra-rápido
- `fzf` - Fuzzy finder interactivo
- `zoxide` - `cd` inteligente que aprende tus rutas
- `jq` - Procesador JSON
- `gh` - GitHub CLI

**Herramientas TUI (reemplazo de GUI):**
- `pulsemixer` - Control de audio TUI (reemplazo de pavucontrol)
- `ranger` - Gestor de archivos TUI (reemplazo de thunar)
- `bluetoothctl` - Control Bluetooth TUI (reemplazo de bluetooth-manager)

**Aliases configurados en fish:**
```bash
ll, la, l, ls → eza (con iconos)
cat → bat
find → fd
grep → rg
audio → pulsemixer
files → ranger
bluetooth → bluetoothctl
```

**Screenshots (Wayland):**
- `Print` - Captura área seleccionada
- `Super + Print` - Captura pantalla completa
- O desde terminal: `screenshot` y `screenshot-full`

**Atajos de teclado en Hyprland:**
- `Super + E` - Abrir Ranger (gestor de archivos TUI)
- `Super + A` - Abrir Pulsemixer (control de audio TUI)
- `Super + U` - Abrir Bluetoothctl (control Bluetooth TUI)
- `Super + W` - Cambiar wallpaper a modo aleatorio
- `Super + Shift + W` - Cambiar wallpaper a modo por hora

### Neovim con LazyVim

LazyVim está configurado para instalarse automáticamente. Después de aplicar la configuración:

```bash
# Aplicar configuración
sudo nixos-rebuild switch --flake .#lemarchand

# Ejecutar Neovim (instalará LazyVim y plugins automáticamente)
nvim
```

**Personalización de LazyVim:**

Edita los archivos en `~/.config/nvim/lua/config/`:
- `keymaps.lua` - Atajos de teclado personalizados
- `options.lua` - Opciones de Neovim
- `autocmds.lua` - Autocomandos personalizados
- `plugins/` - Configuración de plugins adicionales

**Actualizar LazyVim:**

```bash
# Desde dentro de Neovim
:Lazy update

# O desde la terminal
nvim --headless "+Lazy! sync" +qa
```

**Reinstalar LazyVim:**

```bash
# Eliminar configuración actual
rm -rf ~/.config/nvim

# Aplicar configuración de Home Manager (reinstalará LazyVim)
home-manager switch
```

**Recursos:**
- [LazyVim Documentation](https://lazyvim.github.io/)
- [LazyVim GitHub](https://github.com/LazyVim/LazyVim)

### Impresión y Escáner

El sistema incluye soporte completo de impresión con CUPS y el driver unificado de Samsung:

**Configurar impresora:**

```bash
# Abrir interfaz web de CUPS
firefox http://localhost:631

# O usar la interfaz gráfica
system-config-printer

# Ver impresoras disponibles
lpstat -p

# Probar impresión
echo "Test" | lp
```

**Agregar impresora Samsung:**

1. Conecta la impresora por USB o red
2. Abre `system-config-printer` o http://localhost:631
3. Agrega nueva impresora
4. Selecciona el driver Samsung correspondiente a tu modelo

**Comandos útiles:**

```bash
# Listar impresoras
lpstat -p -d

# Ver trabajos de impresión
lpq

# Cancelar trabajo
cancel <job-id>

# Ver estado del servicio CUPS
systemctl status cups
```

**Nota:** El usuario está en los grupos `lp` y `scanner` para acceso a impresoras y escáneres.

### Fish con Fisher y Plugins

El sistema usa Fish como shell con Fisher como gestor de plugins. Los siguientes plugins están configurados:

- **fisher** - El gestor de plugins
- **autopair.fish** - Auto-pareo de brackets y comillas
- **replay.fish** - Replay de comandos
- **fzf.fish** - Integración mejorada de fzf
- **getopts.fish** - Parsing de opciones para scripts
- **hydro** - Prompt minimalista

**Instalación de plugins:**

```bash
# Los plugins se instalan automáticamente al aplicar la configuración
# O manualmente:
fisher install
```

**Configuración:**

Los plugins se configuran automáticamente. El archivo de configuración está en `$XDG_CONFIG_HOME/fish/fish_plugins`.

### Bluetooth

Bluetooth está habilitado con soporte TUI mediante `bluetoothctl`:

**Comandos básicos de Bluetooth:**

```bash
# Abrir interfaz TUI
bluetoothctl

# O desde terminal con comandos directos
bluetoothctl power on          # Encender Bluetooth
bluetoothctl scan on            # Escanear dispositivos
bluetoothctl devices            # Listar dispositivos encontrados
bluetoothctl pair <MAC>         # Emparejar dispositivo
bluetoothctl connect <MAC>      # Conectar dispositivo
bluetoothctl disconnect <MAC>   # Desconectar dispositivo
```

**Atajo de teclado:** `Super + U` abre bluetoothctl en una terminal.

**Verificar estado:**

```bash
# Ver estado del servicio
systemctl status bluetooth

# Ver dispositivos conectados
bluetoothctl devices Connected
```

### Steam Controller

El Steam Controller debería funcionar automáticamente. Si tienes problemas:

```bash
# Verificar que el dispositivo está conectado
lsusb | grep -i steam

# Reiniciar el servicio udev
sudo systemctl restart systemd-udevd
```

### Hardware Específico

**Teclado Apple:**

El sistema está configurado para teclados Apple con `hid_apple` y `fnmode=0`, haciendo que las teclas de función (F1-F12) funcionen por defecto sin necesidad de presionar Fn.

**Cámara web Logitech:**

Soporte completo para cámaras web Logitech mediante el módulo `uvcvideo`. La cámara debería funcionar automáticamente en aplicaciones como Discord, Telegram, etc.

**Monitor USB-C:**

Los monitores USB-C con DisplayPort funcionan automáticamente. Ajusta la configuración de monitores en `~/.config/hypr/hyprland.conf` si es necesario.

**Aplicaciones de comunicación:**

- **Discord** - Cliente estable instalado
- **Telegram Desktop** - Cliente de escritorio instalado
- **Bitwarden** - Cliente de escritorio y CLI (`bw`) para gestión de secretos

---

## 🛠️ Mantenimiento

### Actualizar el Sistema

```bash
# Actualizar flake inputs
cd ~/glowing-octo-potato/lemarchand
nix flake update

# Reconstruir el sistema
sudo nixos-rebuild switch --flake .#lemarchand
```

### Limpiar el Store de Nix

```bash
# Limpieza automática (configurada semanalmente)
# O manualmente:
nix-collect-garbage -d
```

### Verificar Estado de Btrfs

```bash
# Verificar integridad
sudo btrfs scrub status /

# Iniciar scrub manual
sudo btrfs scrub start /
```

---

## 📝 Notas Importantes

1. **Backup de la llave U2F:** Si pierdes tu Google Titan, necesitarás la contraseña de respaldo para acceder al sistema.

2. **UUIDs:** Configura los UUIDs usando variables de entorno (`LUKS_UUID` y `EFI_UUID`) o editando `flake.nix` antes de la instalación. Ver sección "Configurar UUIDs" para más detalles.

3. **Limine:** La configuración de Limine con LUKS requiere trabajo manual. systemd-boot funciona perfectamente como alternativa.

4. **Snapshots:** Considera configurar snapshots automáticos con `snapper` o `btrbk` para mayor protección.

5. **Zona horaria:** Ajusta `time.timeZone` en `configuration.nix` según tu ubicación.

6. **LazyVim:** Se instala automáticamente la primera vez que ejecutes `nvim` después de aplicar la configuración de Home Manager.

---

## 🐛 Solución de Problemas

### No puedo desbloquear el disco con U2F

- Verifica que la llave esté registrada: `sudo systemd-cryptenroll --fido2-device=auto /dev/nvme0n1p2 --list`
- Usa la contraseña de respaldo si es necesario
- Asegúrate de que la llave esté conectada antes de arrancar

### U2F no funciona en login/sudo

- Verifica que el archivo existe: `ls -l /etc/u2f_mappings/daniel`
- Re-registra la llave: `pamu2fcfg -u daniel > ~/.config/Yubico/u2f_keys`
- Verifica permisos: `sudo chmod 644 /etc/u2f_mappings/daniel`

### Steam Controller no funciona

- Verifica reglas udev: `cat /etc/udev/rules.d/*steam*`
- Reinicia udev: `sudo systemctl restart systemd-udevd`
- Verifica que el usuario esté en el grupo `users`

---

## 📚 Recursos

- [Documentación de NixOS](https://nixos.org/manual/nixos/)
- [Home Manager](https://nix-community.github.io/home-manager/)
- [Limine Bootloader](https://github.com/limine-bootloader/limine)
- [Hyprland](https://hyprland.org/)
- [Btrfs Wiki](https://btrfs.wiki.kernel.org/)
- [LazyVim Documentation](https://lazyvim.github.io/)
- [mise (rtx) Documentation](https://mise.jdx.dev/)

---

## 🎉 ¡Listo!

Disfruta de tu nueva workstation NixOS con todas las características de seguridad y productividad configuradas. Si necesitas ayuda adicional, consulta la documentación o abre un issue en el repositorio.

