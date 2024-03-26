{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nuenv.url = "github:DeterminateSystems/nuenv";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    nuenv,
  }: let
    system = "x86_64-linux";
    arch = "x86_64";

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };

    lib = nixpkgs.lib;

    vm-utils = import ./vm-utils.nix {inherit pkgs nixos-generators nuenv;};
  in {
    packages.x86_64-linux.test-image = vm-utils.mkImage {
      inherit system;

      inputs = {inherit pkgs lib;};
      config = {
        pkgs,
        lib,
        ...
      }: {
        system.stateVersion = "24.05";
        boot.kernelPackages = pkgs.linuxPackages_latest;
        environment.systemPackages = [pkgs.vim];
      };
    };

    packages.x86_64-linux.test-appvm = vm-utils.mkQemuAppVm {
      inherit arch;

      name = "test-appvm";
      memorySize = 20000;
      inputs = {inherit pkgs lib;};
      config = {
        pkgs,
        lib,
        ...
      }: {
        system.stateVersion = "24.05";
        boot.kernelPackages = pkgs.linuxPackages_latest;
        boot.kernelParams = ["console=tty0"];
        environment.systemPackages = [pkgs.vim];
        users.users."ghaf" = {
          isNormalUser = true;
          password = "ghaf";
          extraGroups = ["wheel"];
        };
      };
    };

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
  };
}
