{
  description = "Minimal suckless-style NixOS configuration for Gigabyte laptop (Intel iGPU + NVIDIA RTX 4060), Niri now, DWL later";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      username = "nellaror";
    in
    {
      nixosConfigurations.gigabyte-nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit username; };
        modules = [
          ./hosts/system/configuration.nix
          ./hosts/system/hardware-configuration.nix
          ./modules/desktop/niri.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = import ./home/home.nix;
          }
        ];
      };

      # Convenience alias so `nix flake check` / tooling that expects the
      # hostname to match `nixos-rebuild`'s default lookup also works.
      nixosConfigurations.default = self.nixosConfigurations.gigabyte-nixos;
    };
}
