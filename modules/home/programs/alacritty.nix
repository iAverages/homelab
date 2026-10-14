{
  config,
  lib,
  ...
}: let
  cfg = config.programs.alacritty;
in {
  config = lib.mkIf cfg.enable {
    programs.alacritty.settings = {
      env.TERM = "xterm-256color";
      window = {
        decorations = "full";
        opacity = 0.8;
      };
      font.normal = {
        family = "JetBrainsMono Nerd Font";
        style = "Regular";
      };
      scrolling.history = 0;
      general.live_config_reload = true;
      key_bindings = [
        # conflicts with nvim keybind i use
        {
          key = "E";
          mods = "Control";
          action = "None";
        }
      ];
    };
  };
}
