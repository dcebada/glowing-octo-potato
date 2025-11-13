#!/usr/bin/env bash
# Script para cambiar wallpapers dinámicamente en Hyprland
# Soporta: cambio por hora del día, aleatorio, o lista de reproducción
# Usa estándar XDG para rutas

set -euo pipefail

# Usar estándar XDG (XDG_CONFIG_HOME por defecto es ~/.config)
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
WALLPAPER_DIR="${XDG_CONFIG_HOME}/swww/wallpapers"
CONFIG_FILE="${XDG_CONFIG_HOME}/swww/wallpaper-config"

# Crear directorio si no existe
mkdir -p "$WALLPAPER_DIR"

# Función para obtener wallpaper basado en hora del día
get_wallpaper_by_time() {
    local hour
    hour=$(date +%H)
    local wallpaper=""
    
    # Mañana: 06:00 - 11:59
    if [ "$hour" -ge 6 ] && [ "$hour" -lt 12 ]; then
        wallpaper="$WALLPAPER_DIR/morning.jpg"
    # Mediodía: 12:00 - 16:59
    elif [ "$hour" -ge 12 ] && [ "$hour" -lt 17 ]; then
        wallpaper="$WALLPAPER_DIR/afternoon.jpg"
    # Tarde: 17:00 - 19:59
    elif [ "$hour" -ge 17 ] && [ "$hour" -lt 20 ]; then
        wallpaper="$WALLPAPER_DIR/evening.jpg"
    # Noche: 20:00 - 05:59
    else
        wallpaper="$WALLPAPER_DIR/night.jpg"
    fi
    
    # Si el wallpaper específico no existe, usar uno por defecto
    if [ ! -f "$wallpaper" ]; then
        if [ -f "$WALLPAPER_DIR/default.jpg" ]; then
            wallpaper="$WALLPAPER_DIR/default.jpg"
        else
            echo "Error: No se encontró wallpaper para la hora actual ni default.jpg" >&2
            return 1
        fi
    fi
    
    echo "$wallpaper"
}

# Función para obtener wallpaper aleatorio
get_random_wallpaper() {
    local wallpapers
    readarray -t wallpapers < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) 2>/dev/null)
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        if [ -f "$WALLPAPER_DIR/default.jpg" ]; then
            echo "$WALLPAPER_DIR/default.jpg"
        else
            echo "Error: No se encontraron wallpapers en $WALLPAPER_DIR" >&2
            return 1
        fi
        return
    fi
    
    local random_index=$((RANDOM % ${#wallpapers[@]}))
    echo "${wallpapers[$random_index]}"
}

# Función para cambiar wallpaper
set_wallpaper() {
    local wallpaper="$1"
    
    if [ ! -f "$wallpaper" ]; then
        echo "Error: Wallpaper no encontrado: $wallpaper" >&2
        return 1
    fi
    
    # Usar swww para cambiar el wallpaper
    swww img "$wallpaper" --transition-type wipe --transition-duration 2 --transition-fps 60
    
    # Guardar el wallpaper actual
    echo "$wallpaper" > "$CONFIG_FILE.current"
}

# Leer configuración
MODE="time"  # Por defecto: cambio por hora
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Procesar argumentos
case "${1:-}" in
    time|--time)
        MODE="time"
        ;;
    random|--random)
        MODE="random"
        ;;
    set|--set)
        if [ -z "${2:-}" ]; then
            echo "Uso: $0 set <ruta-al-wallpaper>"
            exit 1
        fi
        set_wallpaper "$2"
        exit 0
        ;;
    help|--help|-h)
        echo "Uso: $0 [time|random|set <ruta>]"
        echo ""
        echo "Modos:"
        echo "  time   - Cambia wallpaper según la hora del día (por defecto)"
        echo "  random - Selecciona un wallpaper aleatorio"
        echo "  set    - Establece un wallpaper específico"
        echo ""
        echo "Configuración: Edita $CONFIG_FILE para cambiar el modo por defecto"
        exit 0
        ;;
esac

# Cambiar wallpaper según el modo
case "$MODE" in
    time)
        wallpaper=$(get_wallpaper_by_time)
        ;;
    random)
        wallpaper=$(get_random_wallpaper)
        ;;
    *)
        echo "Modo desconocido: $MODE" >&2
        exit 1
        ;;
esac

set_wallpaper "$wallpaper"

