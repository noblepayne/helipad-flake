{
  description = "nix flake for helipad";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{self, flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } rec {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule
      ];
      systems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.
        let helipadPackage = pkgs.callPackage ./helipad.nix { };
        in rec {
          packages.helipad = helipadPackage.helipad;
	  packages.helipadWebroot = helipadPackage.helipadWebroot;
          packages.default = packages.helipad;
        };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
        nixosModules.default = {config, pkgs, ...}: {
	  imports = [ ./module.nix ];
	  config.services.helipad.pkgs = self.packages.${pkgs.system};
	};
        nixosConfigurations.test123 = nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.default
            {
              boot.loader.grub.device = "nodev";
              fileSystems."/" = {
                device = "none";
                fsType = "tmpfs";
	        options = [ "defaults" "mode=755" ];
              };
              users.users.root.initialPassword = "password";
              services.helipad.enable = true;
            }
          ];
        };
      };
    };
}
