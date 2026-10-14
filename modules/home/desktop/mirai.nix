{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mirai;
in {
  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.awww];
    services.awww.enable = true;
    services.mirai.settings.local.path = "${config.home.homeDirectory}/wallpapers/anime";
  };
}
