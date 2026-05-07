{
  lib,
  config,
  ...
}: let
  cfg = config.homelab;
in {
  imports = [
    ./applications
    ./databases
    ./monitoring
    ./system
    ./options.nix
    ./test.nix
  ];

  options = {
    homelab = {
      enable = lib.mkEnableOption "homelab";
      domain = lib.mkOption {
        type = lib.types.str;
      };
      settings = {
        disableServicelb = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = lib.mkDefault {
      enable = true;
      extraFlags =
        [
          "--disable traefik"
          "--secrets-encryption"
        ]
        ++ lib.optionals cfg.settings.disableServicelb [
          "--disable servicelb"
        ];
    };
  };
}
