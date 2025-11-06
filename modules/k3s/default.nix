{
  lib,
  config,
  ...
}: {
  imports = [./applications ./system ./options.nix];

  options = {
    homelab = {
      enable = lib.mkEnableOption "homelab";
      domain = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf config.homelab.enable {
    services.k3s = lib.mkDefault {
      enable = true;
      extraFlags = [
        "--disable traefik"
        "--disable servicelb"
        "--secrets-encryption"
      ];
    };
  };
}
