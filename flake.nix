{
  description = "Minimal suckless-style NixOS configuration for Gigabyte laptop (Intel iGPU + NVIDIA RTX 4060) with the DWL Wayland compositor";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt nix-index database, refreshed weekly upstream: `,` (comma)
    # and command-not-found work without running `nix-index` locally.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, nix-index-database, ... }:
    let
      system = "x86_64-linux";
      username = "nellaror";
      # Passed to every NixOS and Home Manager module as arguments, see
      # theme/README.md
      theme = import ./theme/everforest.nix;
      font = import ./theme/font.nix;
      args = { inherit username theme font; };
    in
    {
      nixosConfigurations.gigabyte-nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = args;
        modules = [
          ./hosts/system/configuration.nix
          ./hosts/system/hardware-configuration.nix
          ./modules/hardware/nvidia.nix
          ./modules/desktop/dwl.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = args;
            home-manager.users.${username} = import ./home/home.nix;
            home-manager.sharedModules = [ nix-index-database.homeModules.nix-index ];
          }
        ];
      };
    };
}
