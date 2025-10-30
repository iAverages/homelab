{
  description = "homelab";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    inputs,
    self,
    nixpkgs,
  }: let
    hosts = {
      "kurumi" = {};
    };

    mkHost = hostname: attrs:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          system = "x86_64-linux";
          meta = {
            inherit hostname;
            monitors = attrs.monitors;
          };
        };
        modules = [
          ./machines/${hostname}
          ./modules/
        ];
      };
  in {
    nixosConfigurations =
      hosts
      |> nixpkgs.lib.mapAttrs (hostname: attrs: mkHost hostname attrs);
  };
}
