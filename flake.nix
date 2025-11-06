{
  description = "homelab";

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    hostsPath = ./hosts;
    hosts =
      builtins.readDir hostsPath
      |> nixpkgs.lib.attrNames
      |> (names: nixpkgs.lib.filter (name: nixpkgs.lib.filesystem.pathIsDirectory (hostsPath + "/${name}")) names);

    mkHost = hostname:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          system = "x86_64-linux";
        };
        modules = [
          ./hosts/${hostname}
          ./modules
        ];
      };
  in {
    nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

    devShells = flake-utils.lib.eachDefaultSystemMap (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          kubectl
          kubectx
          sops
        ];
      };
    });
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
