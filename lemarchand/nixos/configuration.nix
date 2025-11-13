{ config, pkgs, lib, luksUuid ? "REPLACE-WITH-LUKS-UUID", efiUuid ? "REPLACE-WITH-EFI-UUID", ... }:

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
    "amd_iommu=on"
    "iommu=pt"
    "elevator=none"
    "processor.max_cstate=1"
    "idle=nomwait"
    "amd_pstate=active"
    "transparent_hugepage=madvise"
    "nvme_core.default_ps_max_latency_us=0"
    "rcu_nocbs=0-15"
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
  ];
  boot.initrd.kernelModules = [ "amdgpu" "nvme" ];
  boot.kernelModules = [ "kvm-amd" "uvcvideo" ];
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
  # 3. Sistema de archivos Btrfs
  #################################################################
  btrfsOptions = [
    "compress=zstd:1"
    "ssd_spread"
    "noatime"
    "space_cache=v2"
    "autodefrag"
    "discard=async"
  ];

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
    options = [ "subvol=@nix" "ssd_spread" "noatime" "space_cache=v2" ];
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
    interval = "daily";
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "weekly";
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
      "docker"
      "libvirtd"
      "plugdev"
    ];
    shell = pkgs.fish;
  };
  security.sudo.wheelNeedsPassword = true;

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
    # Steam Controller
    SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1102", MODE="0666"
    KERNEL=="uinput", MODE="0660", GROUP="users", OPTIONS+="static_node=uinput"
    KERNEL=="xpad", MODE="0666"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666"
    
    # Cámara web Logitech (USB Video Class)
    SUBSYSTEM=="video4linux", ATTR{idVendor}=="046d", MODE="0666"
    KERNEL=="video[0-9]*", ATTR{idVendor}=="046d", MODE="0666"
  '';
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "gpl";
    STEAM_COMPAT_CLIENT_INSTALL_PATH = "/home/daniel/.steam/steam";
  };

  #################################################################
  # 7. Red y conectividad
  #################################################################
  networking = {
    hostName = "lemarchand";
    networkmanager.enable = true;
    firewall.enable = true;
    firewall.allowedTCPPorts = [
      631  # CUPS (impresión)
    ];
    firewall.allowedUDPPorts = [
      631  # CUPS (impresión)
    ];
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
    # Soporte para cámaras web (v4l2)
    video.enable = true;
  };

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
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
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
      openFirewall = true;
    };
    blueman.enable = false;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Enable = "Source,Sink,Media,Socket";
    };
    openssh.enable = false;
    journald.extraConfig = ''
      SystemMaxUse=500M
      MaxRetentionSec=1week
    '';
  };
  systemd.services.systemd-udev-settle.enable = false;

  #################################################################
  # 13. Nix configuration (optimizado para Ryzen 9 6900HX)
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
      max-jobs = "auto";
      cores = 0;
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
  # 14. Estado del sistema
  #################################################################
  system.stateVersion = "24.05";
}
