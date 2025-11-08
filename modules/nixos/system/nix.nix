{inputs, ...}: {
  system.stateVersion = "23.11";
  nixpkgs.config.allowUnfree = true;
  nix = {
    nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
      auto-optimise-store = true;
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
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
