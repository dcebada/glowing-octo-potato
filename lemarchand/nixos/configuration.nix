{ config, pkgs, lib, luksUuid ? "REPLACE-WITH-LUKS-UUID", efiUuid ? "REPLACE-WITH-EFI-UUID", ... }:

let
  # Opciones generales optimizadas para SSD NVMe rápido y CPU potente
  btrfsOptions = [
    "compress=zstd:3"  # Nivel 3: mejor compresión, Ryzen 9 puede manejarlo sin problemas
    "ssd_spread"  # Optimización específica para SSD
    "noatime"  # No actualizar tiempos de acceso (reduce escrituras)
    "nodiratime"  # No actualizar tiempos de acceso en directorios
    "space_cache=v2"  # Cache de espacio v2 (más eficiente)
    "discard=async"  # TRIM asíncrono para NVMe (mejor rendimiento)
    "commit=120"  # Commit cada 120 segundos (reduce I/O frecuente en NVMe rápido)
  ];

  # Opciones para /nix (sin compresión, ya que Nix store está comprimido)
  btrfsNixOptions = [
    "ssd_spread"
    "noatime"
    "nodiratime"
    "space_cache=v2"
    "discard=async"
    "commit=120"
  ];
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  #################################################################
  # 1. Configuración básica del sistema
  #################################################################
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      editor = false;
    };
  };

  boot.kernelParams = [
    "quiet"
    "splash"
    "logo"
    "amd_iommu=on"
    "iommu=pt"
    "elevator=none"
    "processor.max_cstate=1"
    "idle=nomwait"
    "amd_pstate=active"
    "transparent_hugepage=madvise"
    "nvme_core.default_ps_max_latency_us=0"
    "rcu_nocbs=0-15"
    # Optimizaciones adicionales para NVMe Samsung
    "nvme_core.io_timeout=4294967295"
    "nvme_core.max_retries=10"
    # zswap: compresión de memoria antes de swap (mejora rendimiento)
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.max_pool_percent=20"
    "zswap.zpool=z3fold"
    # Optimizaciones de rendimiento del kernel
    "nowatchdog"  # Desactivar watchdog para reducir overhead
    "nohz_full=0-15"  # Nohz full para cores (mejor latencia, menos interrupciones)
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "nvme_core"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sr_mod"
    "amdgpu"
    "radeon"
    "uvcvideo"
    "fuse"
  ];
  boot.initrd.kernelModules = [ "amdgpu" "nvme" ];
  boot.kernelModules = [ "kvm-amd" "uvcvideo" "ntfs3" "fuse" ];
  hardware.enableRedistributableFirmware = true;

  # Configuración para teclado Apple (hid_apple)
  boot.extraModprobeConfig = ''
    options hid_apple fnmode=0
  '';

  #################################################################
  # 2. Cifrado LUKS 2 con U2F (Google Titan)
  #################################################################
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/${luksUuid}";
    preLVM = true;
    allowDiscards = true;
    keyFile = null;
  };
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.extraBin = {
    "${pkgs.systemd}/bin/systemd-cryptsetup" = "${pkgs.systemd}/bin/systemd-cryptsetup";
  };

  #################################################################
  # 3. Sistema de archivos Btrfs (optimizado para Ryzen 9 6900HX + Samsung NVMe)
  #################################################################
  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@" ] ++ btrfsOptions;
  };

  fileSystems."/home" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@home" ] ++ btrfsOptions;
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@nix" ] ++ btrfsNixOptions;
  };

  fileSystems."/var/log" = {
    device = "/dev/mapper/cryptroot";
    fsType = "btrfs";
    options = [ "subvol=@var-log" ] ++ btrfsOptions;
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/${efiUuid}";
    fsType = "vfat";
  };

  services.fstrim = {
    enable = true;
    interval = "weekly";  # NVMe no necesita TRIM tan frecuente
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";  # Scrub mensual es suficiente para SSD NVMe moderno
    fileSystems = [ "/" ];
  };

  #################################################################
  # 4. U2F para PAM (login y sudo)
  #################################################################
  security.pam.u2f = {
    enable = true;
    cue = true;
    interactive = true;
  };
  security.pam.services = {
    login.u2fAuth = true;
    sudo.u2fAuth = true;
    su.u2fAuth = true;
  };

  #################################################################
  # 5. Usuario y grupos
  #################################################################
  users.users.daniel = {
    isNormalUser = true;
    description = "Daniel";
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
      "lp"
      "scanner"
      "bluetooth"
      "games"
      "plugdev"
    ];
    # Shell gestionado por Home Manager (programs.fish.enable = true)
    # Autologin habilitado (se inicia automáticamente en TTY1)
  };

  #################################################################
  # 5.1. Deshabilitar login directo de root
  #################################################################
  # Deshabilitar login directo de root (solo acceso mediante sudo)
  users.users.root = {
    hashedPassword = "!";  # Deshabilitar contraseña de root
    shell = "${pkgs.shadow}/bin/nologin";  # Shell que no permite login
  };

  # Configuración de sudo
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;  # Requiere contraseña (o U2F) para sudo
  };

  #################################################################
  # 6. Steam y Steam Controller
  #################################################################
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [ driversi686Linux.amdvlk ];
  };
  services.udev.extraRules = ''
    # Steam Controller (permisos restringidos al grupo games)
    SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1102", MODE="0664", GROUP="games"
    KERNEL=="uinput", MODE="0660", GROUP="games", OPTIONS+="static_node=uinput"
    KERNEL=="xpad", MODE="0664", GROUP="games"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0664", GROUP="games"
    
    # Cámara web Logitech (permisos restringidos al grupo video)
    SUBSYSTEM=="video4linux", ATTR{idVendor}=="046d", MODE="0664", GROUP="video"
    KERNEL=="video[0-9]*", ATTR{idVendor}=="046d", MODE="0664", GROUP="video"
  '';
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "gpl";
  };

  #################################################################
  # 7. Red y conectividad
  #################################################################
  networking = {
    hostName = "lemarchand";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  #################################################################
  # 8. Audio y video (PipeWire)
  #################################################################
  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  
  # Soporte para cámaras web (v4l2) - se instala automáticamente con pipewire
  # El módulo uvcvideo ya está cargado en boot.kernelModules

  #################################################################
  # 9. GPU AMD (Radeon RX 680M)
  #################################################################
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [ amdvlk ];
    extraPackages32 = with pkgs.pkgsi686Linux; [ driversi686Linux.amdvlk ];
  };
  services.xserver.videoDrivers = [ "amdgpu" ];
  boot.kernel.sysctl = {
    # Optimizaciones de memoria para Ryzen 9 6900HX
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
    # Optimizaciones para Btrfs y NVMe
    "vm.swappiness" = 100;  # Aumentar para aprovechar zswap (compresión en RAM)
    "vm.vfs_cache_pressure" = 50;  # Cache de VFS balanceado
    # Optimizaciones de I/O para NVMe
    "vm.dirty_writeback_centisecs" = 1500;  # 15 segundos (mejor para NVMe)
    "vm.dirty_expire_centisecs" = 3000;  # 30 segundos
    # Optimizaciones de red (mejor throughput y latencia)
    "net.core.rmem_max" = 134217728;  # 128MB buffer de recepción
    "net.core.wmem_max" = 134217728;  # 128MB buffer de envío
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";  # TCP receive buffer
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";  # TCP send buffer
    "net.core.netdev_max_backlog" = 5000;  # Mayor backlog para alta carga
    "net.ipv4.tcp_fastopen" = 3;  # Habilitar TCP Fast Open
    "net.ipv4.tcp_slow_start_after_idle" = 0;  # Desactivar slow start después de idle
    # Optimizaciones de scheduler
    "kernel.sched_migration_cost_ns" = 5000000;  # Reducir migración de procesos
    "kernel.sched_autogroup_enabled" = 1;  # Habilitar autogroup (mejor para desktop)
    # Optimizaciones de GPU AMD
    "dev.radeon.modeset" = 1;
    "dev.amdgpu.modeset" = 1;
  };

  #################################################################
  # 10. Zona horaria y localización
  #################################################################
  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "es_ES.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_ES.UTF-8";
    LC_IDENTIFICATION = "es_ES.UTF-8";
    LC_MEASUREMENT = "es_ES.UTF-8";
    LC_MONETARY = "es_ES.UTF-8";
    LC_NAME = "es_ES.UTF-8";
    LC_NUMERIC = "es_ES.UTF-8";
    LC_PAPER = "es_ES.UTF-8";
    LC_TELEPHONE = "es_ES.UTF-8";
    LC_TIME = "es_ES.UTF-8";
  };

  #################################################################
  # 11. Paquetes del sistema
  #################################################################
  environment.systemPackages = with pkgs; [
    # Herramientas básicas
    curl
    git
    btop
    file
    unzip
    zip

    # Herramientas de cifrado y U2F/FIDO2
    cryptsetup
    yubikey-manager
    yubico-pam
    libfido2  # Soporte FIDO2 para Google Titan

    # Herramientas de Btrfs
    btrfs-progs
    snapper  # Para snapshots automáticos (opcional)

    # Herramientas de red
    nmap
    tcpdump

    # Utilidades del sistema
    pciutils
    usbutils
    lshw
    
    # Herramientas de monitoreo de hardware
    radeontop
    nvme-cli
    smartmontools

    # Herramientas de impresión
    cups
    cups-filters

    # Soporte para sistemas de archivos externos
    ntfs3g  # NTFS (compatible con Windows)
    exfatprogs  # exFAT (compatible con macOS y Windows)
    fuse  # Sistema de archivos en espacio de usuario

    # Firewall
    ufw  # Uncomplicated Firewall

    # Boot splash
    plymouth  # Boot splash screen con logo
  ];

  #################################################################
  # 12. Servicios del sistema
  #################################################################
  services = {
    printing = {
      enable = true;
      drivers = with pkgs; [ samsung-unified-linux-driver ];
    };
    avahi = {
      enable = true;
      nssmdns = true;
      openFirewall = false;
    };
    openssh.enable = false;
    journald.extraConfig = ''
      SystemMaxUse=500M
      MaxRetentionSec=1week
    '';
    udisks2.enable = true;
  };
  systemd.services.systemd-udev-settle.enable = false;

  #################################################################
  # 12.1. Bluetooth
  #################################################################
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
  services.blueman.enable = false;

  #################################################################
  # 13. UFW (Uncomplicated Firewall)
  #################################################################
  systemd.services.ufw = {
    description = "Uncomplicated Firewall";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.ufw}/bin/ufw --force enable";
    };
  };

  # Configurar UFW al activar el sistema
  system.activationScripts.ufw = ''
    # Configurar políticas por defecto
    ${pkgs.ufw}/bin/ufw --force reset
    ${pkgs.ufw}/bin/ufw default deny incoming
    ${pkgs.ufw}/bin/ufw default allow outgoing
    ${pkgs.ufw}/bin/ufw default deny routed

    # Permitir CUPS (impresión) desde localhost
    ${pkgs.ufw}/bin/ufw allow from 127.0.0.1 to any port 631 proto tcp
    ${pkgs.ufw}/bin/ufw allow from 127.0.0.1 to any port 631 proto udp

    # Permitir CUPS desde red local
    ${pkgs.ufw}/bin/ufw allow from 192.168.0.0/16 to any port 631 proto tcp
    ${pkgs.ufw}/bin/ufw allow from 10.0.0.0/8 to any port 631 proto tcp

    # Permitir Steam Remote Play
    ${pkgs.ufw}/bin/ufw allow 27036/udp
    ${pkgs.ufw}/bin/ufw allow 27036/tcp

    # Permitir Steam Link
    ${pkgs.ufw}/bin/ufw allow 27031/udp
    ${pkgs.ufw}/bin/ufw allow 27031/tcp

    # Habilitar UFW
    ${pkgs.ufw}/bin/ufw --force enable
  '';

  #################################################################
  # 14. Autologin y Plymouth (boot splash)
  #################################################################
  # Autologin para usuario daniel en TTY1
  services.getty.autologinUser = "daniel";

  # Plymouth boot splash con logo
  boot.plymouth = {
    enable = true;
    theme = "bgrt";  # Usa el logo del firmware (si está disponible)
    # Alternativamente, puedes usar "spinner" o crear un tema personalizado
  };

  #################################################################
  # 15. Nix configuration (optimizado para Ryzen 9 6900HX)
  #################################################################
  nix = {
    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "daniel" ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      max-jobs = 16;  # Usar todos los cores del Ryzen 9 6900HX (8 cores, 16 threads)
      cores = 16;  # Número de cores para builds paralelos
      # Optimizaciones de build
      builders-use-substitutes = true;  # Usar substituters en builders
      keep-outputs = true;  # Mantener outputs para builds incrementales
      keep-derivations = true;  # Mantener derivaciones para debugging
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  #################################################################
  # 16. Estado del sistema
  #################################################################
  system.stateVersion = "24.05";
}
