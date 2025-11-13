# Este archivo se genera automáticamente con:
#   nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# O durante la instalación con:
#   nixos-generate-config --root /mnt
#
# IMPORTANTE: Esta es una plantilla básica. Debes ejecutar el comando anterior
# en tu máquina para obtener la configuración específica de tu hardware.
#
# Después de generar el archivo, cópialo al repositorio:
#   sudo cp /mnt/etc/nixos/hardware-configuration.nix nixos/hardware-configuration.nix
#
# Nota: Los parámetros del kernel específicos de AMD (amd_pstate=active, etc.)
# están configurados en nixos/configuration.nix, no aquí.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
  powerManagement.powertop.enable = true;

  # Ajustes de swap (si es necesario)
  # swapDevices = [ ];
}

