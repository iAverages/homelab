{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gtk;
in {
  config = lib.mkIf cfg.enable {
    gtk = {
      cursorTheme = {
        name = "ZhuangFangyi";
        size = lib.mkDefault 24;
      };
      gtk4.theme = cfg.theme;
      iconTheme = {
        name = "breeze-dark";
        package = pkgs.kdePackages.breeze-icons;
      };
      theme.name = "rose-pine";
    };

    home.sessionVariables = {
      XCURSOR_THEME = "ZhuangFangyi";
      XCURSOR_SIZE = toString cfg.cursorTheme.size;
    };
  };
}
