{
  description = "homelab";

  outputs = {
    nixpkgs,
    disko,
    sops-nix,
    flake-utils,
    comin,
    nixflix,
    home-manager,
    noctalia,
    mirai,
    ...
  } @ inputs: let
    hostsPath = ./hosts;
    hosts =
      builtins.readDir hostsPath
      |> nixpkgs.lib.attrNames
      |> (names: nixpkgs.lib.filter (name: nixpkgs.lib.filesystem.pathIsDirectory (hostsPath + "/${name}")) names);

    homeHosts = nixpkgs.lib.filter (hostname: builtins.pathExists (hostsPath + "/${hostname}/home.nix")) hosts;
    nixosHomeHosts = ["kurumi"];
    standaloneHomeHosts = nixpkgs.lib.subtractLists nixosHomeHosts homeHosts;

    homeModules = [
      sops-nix.homeManagerModules.sops
      noctalia.homeModules.default
      mirai.homeManagerModules.default
      ./modules/home
    ];

    mkHost = hostname:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          system = "x86_64-linux";
        };
        modules =
          [
            sops-nix.nixosModules.sops
            disko.nixosModules.disko
            comin.nixosModules.comin
            nixflix.nixosModules.default

            ./modules/nixos/system/nix.nix
            ./hosts/${hostname}
            ./modules
          ]
          ++ nixpkgs.lib.optionals (builtins.elem hostname nixosHomeHosts) [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {inherit inputs hostname;};
                sharedModules = homeModules;
                users.dan = import ./hosts/${hostname}/home.nix;
              };
            }
          ];
      };

    mkHome = hostname:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = import ./modules/lib {};
        };
        extraSpecialArgs = {
          inherit inputs hostname;
        };
        modules = homeModules ++ [./hosts/${hostname}/home.nix];
      };
  in {
    nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

    homeConfigurations =
      standaloneHomeHosts
      |> map (hostname: nixpkgs.lib.nameValuePair "dan@${hostname}" (mkHome hostname))
      |> builtins.listToAttrs;

    devShells = flake-utils.lib.eachDefaultSystemMap (system: let
      pkgs = import nixpkgs {
        inherit system;
      };
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          fluxcd
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

        shellHook = ''
          tofu_repo_root="$PWD"
          while [[ "$tofu_repo_root" != / && ! -x "$tofu_repo_root/scripts/tofu" ]]; do
            tofu_repo_root="$(dirname "$tofu_repo_root")"
          done

          if [[ -x "$tofu_repo_root/scripts/tofu" ]]; then
            export PATH="$tofu_repo_root/scripts:$PATH"
          fi

          unset tofu_repo_root
        '';
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
    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-stable.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    hyprland.url = "github:hyprwm/Hyprland";
    llm-agents.url = "github:numtide/llm-agents.nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mirai = {
      url = "github:iaverages/mirai";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    visual-diff = {
      url = "git+https://git.kirsi.dev/SLOP/visual-diff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fran-db = {
      url = "github:SalahaldinBilal/fran-db";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
