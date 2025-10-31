{
  description = "homelab";

  outputs = {nixpkgs, ...} @ inputs: let
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
    nixosConfigurations =
      nixpkgs.lib.genAttrs hosts mkHost;

    devShells.default = with nixpkgs;
      mkShell {
        packages = [
          nodejs_24
          pnpm
          pkg-config
          openssl
          just
          mprocs
          rust
        ];
      };
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
