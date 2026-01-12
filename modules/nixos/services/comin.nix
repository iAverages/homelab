{
  lib,
  config,
  ...
}: let
  cfg = config.services.config-git-deploy;
in {
  options.services.config-git-deploy = {
    enable = lib.mkEnableOption "comin";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/iAverages/homelab";
    };
    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
    };
  };

  config = lib.mkIf cfg.enable {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = cfg.url;
          branches.main.name = cfg.branch;
        }
      ];
    };
  };
}
