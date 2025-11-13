{
  description = "lemarchand – NixOS con Limine, LUKS‑U2F y entorno Omarchy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, unstable, home-manager, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgsConfig = { allowUnfree = true; };
      pkgsStable = import nixpkgs { inherit system; config = pkgsConfig; };
      pkgsUnstable = import unstable { inherit system; config = pkgsConfig; };
      luksUuidEnv = builtins.getEnv "LUKS_UUID";
      efiUuidEnv = builtins.getEnv "EFI_UUID";
      luksUuid = if luksUuidEnv != "" then luksUuidEnv else "REPLACE-WITH-LUKS-UUID";
      efiUuid = if efiUuidEnv != "" then efiUuidEnv else "REPLACE-WITH-EFI-UUID";
    in {
      nixosConfigurations.lemarchand = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          unstable = pkgsUnstable;
          luksUuid = luksUuid;
          efiUuid = efiUuid;
        };
        modules = [
          ./nixos/hardware-configuration.nix
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              unstable = pkgsUnstable;
            };
            home-manager.users.daniel = import ./home/daniel/home.nix;
          }
        ];
      };
    };
}