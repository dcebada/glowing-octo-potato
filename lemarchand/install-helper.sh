#!/usr/bin/env bash
# Script de ayuda para la instalación de lemarchand
# Este script ayuda a obtener los UUIDs necesarios para configuration.nix

set -euo pipefail  # Más estricto: -u detecta variables no definidas, -o pipefail detecta errores en pipes

echo "=========================================="
echo "  lemarchand - Helper de Instalación"
echo "=========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Por favor, ejecuta este script con sudo${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Detectando dispositivos de almacenamiento...${NC}"
echo ""
lsblk
echo ""

echo -e "${YELLOW}2. UUIDs de particiones:${NC}"
echo ""

# Buscar partición EFI (mejorado: múltiples métodos)
EFI_PART=""
# Método 1: Buscar por PARTTYPE
EFI_PART=$(lsblk -o NAME,PARTTYPE,FSTYPE | grep -iE "(c12a732f-f81f-11d2-ba4b-00a0c93ec93b|EFI|vfat)" | head -1 | awk '{print $1}' || true)

# Método 2: Buscar por FSTYPE vfat en particiones pequeñas
if [ -z "$EFI_PART" ]; then
    EFI_PART=$(lsblk -o NAME,SIZE,FSTYPE | grep -i "vfat" | awk '{print $1}' | head -1 || true)
fi

if [ -n "$EFI_PART" ] && [ -e "/dev/$EFI_PART" ]; then
    EFI_UUID=$(blkid -s UUID -o value "/dev/$EFI_PART" 2>/dev/null || echo "NO ENCONTRADO")
    EFI_SIZE=$(lsblk -o SIZE -n "/dev/$EFI_PART" 2>/dev/null || echo "N/A")
    echo -e "${GREEN}Partición EFI:${NC} /dev/$EFI_PART (${EFI_SIZE})"
    echo -e "  UUID: ${GREEN}$EFI_UUID${NC}"
    echo "  → Configura EFI_UUID en variables de entorno o flake.nix"
    echo ""
else
    echo -e "${RED}No se encontró partición EFI${NC}"
    echo "  Busca manualmente con: lsblk -o NAME,PARTTYPE,FSTYPE"
    echo ""
fi

# Buscar dispositivos LUKS
echo -e "${YELLOW}3. Dispositivos LUKS:${NC}"
echo ""
LUKS_DEVICES=$(lsblk -o NAME,TYPE | grep crypt | awk '{print $1}' || true)
if [ -z "$LUKS_DEVICES" ]; then
    echo -e "${YELLOW}No hay dispositivos LUKS abiertos actualmente${NC}"
    echo "  Abre tu dispositivo LUKS con: cryptsetup open /dev/nvme0n1p2 cryptroot"
    echo ""
else
    for dev in $LUKS_DEVICES; do
        LUKS_UUID=$(blkid -s UUID -o value /dev/mapper/$dev 2>/dev/null || echo "NO ENCONTRADO")
        echo -e "${GREEN}Dispositivo LUKS:${NC} /dev/mapper/$dev"
        echo -e "  UUID: ${GREEN}$LUKS_UUID${NC}"
    done
    echo ""
fi

# Buscar particiones LUKS sin abrir (optimizado: mejor detección)
echo -e "${YELLOW}4. Particiones LUKS (sin abrir):${NC}"
echo ""
LUKS_FOUND=false
DETECTED_LUKS_UUID=""
while IFS= read -r line; do
    part=$(echo "$line" | awk '{print $1}')
    if [ -n "$part" ] && [ -e "/dev/$part" ]; then
        if cryptsetup isLuks "/dev/$part" 2>/dev/null; then
            LUKS_PART_UUID=$(blkid -s UUID -o value "/dev/$part" 2>/dev/null || echo "NO ENCONTRADO")
            PART_SIZE=$(lsblk -o SIZE -n "/dev/$part" 2>/dev/null || echo "N/A")
            echo -e "${GREEN}Particion LUKS:${NC} /dev/$part (${PART_SIZE})"
            echo -e "  UUID: ${GREEN}$LUKS_PART_UUID${NC}"
            echo "  → Configura LUKS_UUID en variables de entorno o flake.nix"
            echo ""
            LUKS_FOUND=true
            if [ -z "$DETECTED_LUKS_UUID" ] && [ "$LUKS_PART_UUID" != "NO ENCONTRADO" ]; then
                DETECTED_LUKS_UUID="$LUKS_PART_UUID"
            fi
        fi
    fi
done < <(lsblk -o NAME,TYPE | grep -E "part|disk" | awk '{print $1}')

if [ "$LUKS_FOUND" = false ]; then
    echo -e "${YELLOW}  No se encontraron particiones LUKS${NC}"
    echo "  Crea una con: cryptsetup luksFormat /dev/nvme0n1p2"
    echo ""
fi

# Capturar UUID de EFI detectado
DETECTED_EFI_UUID=""
if [ -n "$EFI_PART" ] && [ -e "/dev/$EFI_PART" ]; then
    DETECTED_EFI_UUID=$(blkid -s UUID -o value "/dev/$EFI_PART" 2>/dev/null || echo "")
fi

echo -e "${YELLOW}5. Verificando montajes actuales:${NC}"
echo ""
if mountpoint -q /mnt; then
    echo -e "${GREEN}✓ Sistema montado en /mnt${NC}"
    mount | grep /mnt
else
    echo -e "${RED}✗ Sistema no montado en /mnt${NC}"
    echo "  Monta el sistema antes de continuar"
fi
echo ""

echo -e "${YELLOW}6. Verificando estructura de directorios:${NC}"
echo ""
REQUIRED_DIRS=("/mnt/boot/efi" "/mnt/home" "/mnt/nix" "/mnt/var/log")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir"
    else
        echo -e "${RED}✗${NC} $dir (falta crear)"
    fi
done
echo ""

echo -e "${YELLOW}7. Verificando subvolúmenes Btrfs:${NC}"
echo ""
if mountpoint -q /mnt && command -v btrfs &> /dev/null; then
    ROOT_DEV=$(findmnt -n -o SOURCE /mnt)
    if [ -n "$ROOT_DEV" ]; then
        echo "Subvolúmenes en $ROOT_DEV:"
        btrfs subvolume list /mnt 2>/dev/null || echo "  No se pudieron listar subvolúmenes"
    fi
else
    echo "  No se puede verificar (sistema no montado o btrfs no disponible)"
fi
echo ""

echo "=========================================="
echo -e "${YELLOW}8. Parámetros configurables del flake:${NC}"
echo "=========================================="
echo ""

# Verificar variables de entorno actuales
LUKS_UUID_ENV="${LUKS_UUID:-}"
EFI_UUID_ENV="${EFI_UUID:-}"
GIT_EMAIL_ENV="${GIT_EMAIL:-}"

echo -e "${GREEN}Parámetros del sistema (flake.nix):${NC}"
echo ""
echo -e "  ${YELLOW}LUKS_UUID${NC} - UUID de la partición LUKS cifrada"
if [ -n "$LUKS_UUID_ENV" ]; then
    echo -e "    ${GREEN}✓ Configurado:${NC} $LUKS_UUID_ENV"
else
    echo -e "    ${RED}✗ No configurado${NC} (usará valor por defecto: REPLACE-WITH-LUKS-UUID)"
    if [ -n "$DETECTED_LUKS_UUID" ]; then
        echo -e "    ${YELLOW}→ UUID detectado:${NC} $DETECTED_LUKS_UUID"
        echo -e "    ${YELLOW}→ Ejecuta:${NC} export LUKS_UUID=\"$DETECTED_LUKS_UUID\""
    elif [ -n "$LUKS_DEVICES" ]; then
        echo -e "    ${YELLOW}→ Revisa el UUID mostrado arriba en dispositivos LUKS abiertos${NC}"
    fi
fi
echo ""

echo -e "  ${YELLOW}EFI_UUID${NC} - UUID de la partición EFI"
if [ -n "$EFI_UUID_ENV" ]; then
    echo -e "    ${GREEN}✓ Configurado:${NC} $EFI_UUID_ENV"
else
    echo -e "    ${RED}✗ No configurado${NC} (usará valor por defecto: REPLACE-WITH-EFI-UUID)"
    if [ -n "$DETECTED_EFI_UUID" ]; then
        echo -e "    ${YELLOW}→ UUID detectado:${NC} $DETECTED_EFI_UUID"
        echo -e "    ${YELLOW}→ Ejecuta:${NC} export EFI_UUID=\"$DETECTED_EFI_UUID\""
    fi
fi
echo ""

echo -e "${GREEN}Parámetros de usuario (home.nix):${NC}"
echo ""
echo -e "  ${YELLOW}GIT_EMAIL${NC} - Email para configuración de Git"
if [ -n "$GIT_EMAIL_ENV" ]; then
    echo -e "    ${GREEN}✓ Configurado:${NC} $GIT_EMAIL_ENV"
else
    echo -e "    ${RED}✗ No configurado${NC} (usará valor por defecto: daniel@example.com)"
    echo -e "    ${YELLOW}→ Configura tu email real para commits de Git${NC}"
fi
echo ""

echo "=========================================="
echo -e "${GREEN}Comandos para configurar variables:${NC}"
echo "=========================================="
echo ""
echo "Opción 1: Exportar variables de entorno (recomendado)"
echo "  export LUKS_UUID=\"tu-uuid-luks-aqui\""
echo "  export EFI_UUID=\"tu-uuid-efi-aqui\""
echo "  export GIT_EMAIL=\"tu-email@ejemplo.com\""
echo ""
echo "Opción 2: Crear archivo .env (si usas direnv o similar)"
echo "  cat > .env <<EOF"
echo "  export LUKS_UUID=\"tu-uuid-luks-aqui\""
echo "  export EFI_UUID=\"tu-uuid-efi-aqui\""
echo "  export GIT_EMAIL=\"tu-email@ejemplo.com\""
echo "  EOF"
echo ""
echo "Opción 3: Editar directamente flake.nix y home.nix"
echo "  - Edita flake.nix líneas 21-22 para UUIDs"
echo "  - Edita home/daniel/home.nix línea 4 para GIT_EMAIL"
echo ""

echo "=========================================="
echo -e "${GREEN}Resumen de pasos siguientes:${NC}"
echo "=========================================="
echo "1. Configura las variables de entorno (ver arriba)"
echo "2. Genera hardware-configuration.nix:"
echo "   sudo nixos-generate-config --root /mnt"
echo "3. Copia hardware-configuration.nix al repositorio"
echo "4. Verifica la configuración:"
echo "   sudo nixos-install --flake .#lemarchand --root /mnt --dry-run"
echo "5. Instala el sistema:"
echo "   sudo nixos-install --flake .#lemarchand --root /mnt"
echo ""
echo -e "${YELLOW}Tip:${NC} Usa '--show-trace' si hay errores para más detalles"
echo ""

