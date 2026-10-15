{
  config,
  inputs,
  lib,
  ...
}: {
  system.stateVersion = "23.11";
  nixpkgs = {
    config.allowUnfree = true;
    overlays = import ../../lib {};
  };
  nix = {
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        # lix and nix use different names for the same feature
        (
          if lib.getName config.nix.package == "lix"
          then "pipe-operator"
          else "pipe-operators"
        )
      ];
      auto-optimise-store = true;
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://cache-storage.kirsi.dev"
      ];
      trusted-substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://cache-storage.kirsi.dev"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache-storage.kirsi.dev-1:kobyAUhAcq9OMNdNJCX6R0zz5GZ7OGv8SP7uJxcH8Cw="
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      allowed-users = [
        "root"
        "@wheel"
      ];
    };
  };
}
