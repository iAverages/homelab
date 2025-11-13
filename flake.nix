{
  description = "homelab";

  outputs = {
    self,
    nixpkgs,
    disko,
    sops-nix,
    deploy-rs,
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
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./hosts/${hostname}
          ./modules
        ];
      };
  in {
    nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    deploy.nodes.kurumi = {
      hostname = "192.168.1.202";
      profiles.system = {
        user = "root";
        sshUser = "root";
        # interactiveSudo = true;
        remoteBuild = true;
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.kurumi;
      };
    };

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
          pkgs.deploy-rs
        ];
      };
    });
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    deploy-rs.url = "github:serokell/deploy-rs";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
