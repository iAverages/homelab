{
  config,
  lib,
  ...
}: let
  cfg = config.programs.ghostty;
in {
  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      installBatSyntax = true;
      installVimSyntax = true;
      settings = {
        font-size = 11.25;
        font-family = "JetBrainsMono Nerd Font";
        adjust-cell-height = 1;
        background = "#181818";
        background-opacity = 0.8;
        scrollback-limit = 0;
        window-decoration = false;
        mouse-scroll-multiplier = 0.5;

        keybind = ["ctrl+shift+left=unbind" "ctrl+shift+right=unbind"];
      };
    };
  };
}
