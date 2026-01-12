{
  description = "homelab";

  outputs = {
    nixpkgs,
    disko,
    sops-nix,
    flake-utils,
    comin,
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
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          comin.nixosModules.comin

          ./modules/nixos/system/nix.nix
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
          (opentofu.withPlugins (
            p:
              with p; [
                hashicorp_null
                hashicorp_external
              ]
          ))
        ];
      };
    });
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
