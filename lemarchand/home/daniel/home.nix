{ config, pkgs, lib, unstable, ... }:
let
  gitEmailEnv = builtins.getEnv "GIT_EMAIL";
  gitEmail = if gitEmailEnv != "" then gitEmailEnv else "daniel@example.com";
in
{
  home.username = "daniel";
  home.homeDirectory = "/home/daniel";
  home.stateVersion = "24.05";

  #################################################################
  # 1. Paquetes principales
  #################################################################
  home.packages = with pkgs; [
    # Terminal y fuente
    unstable.ghostty  # Terminal moderno y rápido para Wayland
    victor-mono-nerd-font  # Fuente monoespaciada con iconos Nerd Fonts
    
    # Gestor de versiones
    unstable.mise  # Gestor de versiones de herramientas (rtx)
    
    # Gaming
    steam  # Plataforma de juegos
    unstable.steamcontroller  # Soporte para Steam Controller
    
    # Entorno de escritorio (Hyprland stack)
    unstable.waybar  # Barra de estado para Wayland
    unstable.hyprland  # Compositor Wayland
    unstable.swww  # Gestor de wallpapers para Wayland
    unstable.mako  # Notificaciones para Wayland
    
    # Monitoreo de sistema
    radeontop  # Monitor de GPU AMD en tiempo real
    
    # Launchers y aplicaciones
    wofi  # Launcher de aplicaciones para Wayland
    neovim  # Editor de texto moderno
    brightnessctl  # Control de brillo de pantalla
    
    # Utilidades Wayland
    wl-clipboard  # Portapapeles para Wayland
    grim  # Captura de pantalla para Wayland
    slurp  # Selección de área para screenshots
    wf-recorder  # Grabación de pantalla para Wayland
    playerctl  # Control de reproductores multimedia
    
    # Herramientas TUI
    pulsemixer  # Control de audio TUI
    ranger  # Gestor de archivos TUI
    bluez  # Bluetooth (incluye bluetoothctl TUI)
    bluez-tools  # Herramientas adicionales de Bluetooth
    
    # Control de versiones
    git  # Sistema de control de versiones
    gh  # GitHub CLI
    
    # Red y web
    curl  # Cliente HTTP/HTTPS
    
    # Procesamiento de datos
    jq  # Procesador JSON
    
    # Búsqueda y navegación
    ripgrep  # Búsqueda de texto ultra-rápida (rg)
    fd  # Búsqueda de archivos rápida (alternativa a find)
    fzf  # Fuzzy finder interactivo
    zoxide  # Navegación inteligente de directorios (cd mejorado)
    
    # Visualización de archivos
    bat  # Cat con syntax highlighting
    eza  # ls moderno con iconos y colores
    tree  # Visualización de árbol de directorios
    
    # Utilidades del sistema
    file  # Identificación de tipo de archivo
    unzip  # Extracción de archivos ZIP
    zip  # Compresión de archivos ZIP
    rsync  # Sincronización de archivos
    
    # Multiplexores de terminal
    tmux  # Multiplexor de terminal con paneles
    
    # Wallpapers dinámicos
    mpvpaper  # Wallpapers animados (videos) para Wayland
    
    # Comunicación y mensajería
    discord  # Cliente de Discord (versión estable)
    telegram-desktop  # Cliente de Telegram con interfaz gráfica
    
    # Gestión de secretos
    bitwarden-cli  # CLI de Bitwarden (bw)
    bitwarden  # Cliente de escritorio de Bitwarden
  ];

  #################################################################
  # 2. Ghostty
  #################################################################
  xdg.configFile."ghostty/config.toml".text = ''
    font = "VictorMono Nerd Font Italic 13"
    cursor_style = "beam"
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    opacity = 0.95
    scrollback_lines = 8000
    enable_ligatures = true
    true_color = true
  '';

  #################################################################
  # 3. Fish con Fisher y plugins
  #################################################################
  programs.fish = {
    enable = true;
    shellAliases = {
      ll = "eza -lah --icons";
      la = "eza -A --icons";
      l = "eza --icons";
      ls = "eza --icons";
      cat = "bat";
      find = "fd";
      grep = "rg";
      rebuild = "sudo nixos-rebuild switch --flake ~/glowing-octo-potato/lemarchand#lemarchand";
      update = "cd ~/glowing-octo-potato/lemarchand && nix flake update";
      screenshot = "grim -g (slurp) ~/Pictures/screenshot-(date +%Y%m%d-%H%M%S).png";
      screenshot-full = "grim ~/Pictures/screenshot-(date +%Y%m%d-%H%M%S).png";
      audio = "pulsemixer";
      files = "ranger";
      bluetooth = "bluetoothctl";
    };
    shellInit = ''
      if command -v mise >/dev/null 2>&1
        mise activate fish | source
      end
      if command -v zoxide >/dev/null 2>&1
        zoxide init fish | source
      end
      if test -f ${pkgs.fzf}/share/fzf/key-bindings.fish
        source ${pkgs.fzf}/share/fzf/key-bindings.fish
      end
    '';
    interactiveShellInit = ''
      set -g fish_greeting ""
      set -gx EDITOR nvim
    '';
  };

  # Instalar Fisher y plugins populares
  home.activation.installFisher = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    FISH_CONFIG_DIR="$HOME/.config/fish"
    FISHER_DIR="$FISH_CONFIG_DIR/functions"
    FISHER_PLUGINS_DIR="$FISH_CONFIG_DIR/fish_plugins"
    
    # Instalar Fisher si no existe
    if [ ! -f "$FISHER_DIR/fisher.fish" ]; then
      echo "🐟 Instalando Fisher..."
      mkdir -p "$FISH_CONFIG_DIR/functions"
      curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish -o "$FISHER_DIR/fisher.fish"
    fi
    
    # Crear archivo de plugins si no existe
    if [ ! -f "$FISHER_PLUGINS_DIR" ]; then
      mkdir -p "$FISH_CONFIG_DIR"
      cat > "$FISHER_PLUGINS_DIR" <<EOF
jorgebucaran/fisher
jorgebucaran/autopair.fish
jorgebucaran/replay.fish
PatrickF1/fzf.fish
jorgebucaran/getopts.fish
jorgebucaran/hydro
EOF
      echo "📦 Plugins de Fisher configurados"
      echo "💡 Ejecuta 'fisher install' en una sesión de Fish para instalar los plugins"
    fi
  '';

  #################################################################
  # 4. Waybar, Mako, Swww
  #################################################################
  xdg.configFile."waybar/config".source = ./waybar/config;
  xdg.configFile."waybar/style.css".source = ./waybar/style.css;

  xdg.configFile."mako/config".text = ''
    [global]
    font = VictorMono Nerd Font 11
    background-color = #1e1e2e
    text-color = #cdd6f4
    border-radius = 8
    padding = 12
    margin = 8
    width = 350
  '';

  # Script para wallpapers dinámicos (usa estándar XDG)
  xdg.configFile."swww/wallpaper-dynamic.sh".source = ./scripts/wallpaper-dynamic.sh;
  xdg.configFile."swww/wallpaper-dynamic.sh".executable = true;
  
  # Configuración de wallpaper dinámico
  xdg.configFile."swww/wallpaper-config".text = ''
    # Modo de wallpaper dinámico
    # Opciones: "time" (cambia según hora del día) o "random" (aleatorio)
    MODE="time"
  '';

  # Crear directorio de wallpapers (usa estándar XDG)
  # Los wallpapers se colocan en $XDG_CONFIG_HOME/swww/wallpapers/
  # Ver README.md principal para documentación completa

  # Timer de systemd para cambiar wallpaper cada hora
  systemd.user.timers.wallpaper-dynamic = {
    Unit.Description = "Cambiar wallpaper dinámico cada hora";
    Timer.OnCalendar = "hourly";
    Timer.Persistent = true;
    Install.WantedBy = [ "timers.target" ];
  };
  systemd.user.services.wallpaper-dynamic = {
    Unit.Description = "Cambiar wallpaper dinámico";
    Service.Type = "oneshot";
    Service.Environment = [ "XDG_CONFIG_HOME=${config.xdg.configHome}" ];
    Service.ExecStart = "${config.xdg.configHome}/swww/wallpaper-dynamic.sh";
  };

  #################################################################
  # 5. Hyprland
  #################################################################
  xdg.configFile."hypr/hyprland.conf".source = ./hyprland/hyprland.conf;

  #################################################################
  # 6. Neovim con LazyVim
  #################################################################
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
  home.activation.installLazyVim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LAZYVIM_DIR="$HOME/.config/nvim"
    LAZYVIM_LUA="$LAZYVIM_DIR/lua"
    
    # Solo instalar si no existe la estructura de LazyVim
    if [ ! -d "$LAZYVIM_LUA" ] || [ ! -f "$LAZYVIM_DIR/init.lua" ]; then
      echo "📦 Instalando LazyVim starter template..."
      
      # Backup de configuración existente (si hay algo que no sea LazyVim)
      if [ -d "$LAZYVIM_DIR" ] && [ "$(ls -A $LAZYVIM_DIR 2>/dev/null)" ]; then
        BACKUP_DIR="$LAZYVIM_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        echo "💾 Haciendo backup de configuración existente en $BACKUP_DIR"
        mv "$LAZYVIM_DIR" "$BACKUP_DIR" 2>/dev/null || true
      fi
      
      # Crear directorio si no existe
      mkdir -p "$LAZYVIM_DIR"
      
      # Clonar LazyVim starter template
      TMP_DIR=$(mktemp -d)
      if git clone --filter=blob:none --depth=1 https://github.com/LazyVim/starter "$TMP_DIR" 2>/dev/null; then
        # Mover archivos (incluyendo archivos ocultos)
        shopt -s dotglob
        mv "$TMP_DIR"/* "$LAZYVIM_DIR/" 2>/dev/null || true
        shopt -u dotglob
        rmdir "$TMP_DIR" 2>/dev/null || true
        echo "✅ LazyVim instalado correctamente"
        echo "🚀 Ejecuta 'nvim' para completar la instalación de plugins"
      else
        echo "❌ Error al instalar LazyVim. Instálalo manualmente con:"
        echo "   git clone https://github.com/LazyVim/starter ~/.config/nvim"
        rmdir "$TMP_DIR" 2>/dev/null || true
      fi
    fi
  '';

  #################################################################
  # 7. Servicios de usuario
  #################################################################
  services = {
    pipewire.enable = true;
    mako.enable = true;
    swww.enable = true;
  };

  #################################################################
  # 8. Git
  #################################################################
  programs.git = {
    enable = true;
    userName = "Daniel";
    userEmail = gitEmail;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
      feature.manyFiles = true;
      core.untrackedCache = true;
      color.ui = "auto";
      alias.st = "status";
      alias.co = "checkout";
      alias.br = "branch";
      alias.cm = "commit";
    };
  };

  #################################################################
  # 9. GitHub CLI
  #################################################################
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      editor = "nvim";
    };
  };

  #################################################################
  # 10. Tmux
  #################################################################
  programs.tmux = {
    enable = true;
    clock24 = true;
    keyMode = "vi";
    terminal = "screen-256color";
    extraConfig = ''
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %
      set -g mouse on
      set -g default-terminal "screen-256color"
      set -ga terminal-overrides ",*256col*:Tc"
    '';
  };
}