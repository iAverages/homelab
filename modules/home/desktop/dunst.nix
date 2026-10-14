{
  config,
  lib,
  ...
}: let
  cfg = config.services.dunst;
in {
  config = lib.mkIf cfg.enable {
    services.dunst = {
      settings = {
        global = {
          font = "JetBrainsMono Nerd Font";
          format = "<b>%a</b>\n<i>%s</i>%p %n\n%b";
          sort = true;
          indicate_hidden = true;
          alignment = "left";
          show_age_threshold = 60;
          word_wrap = true;
          ignore_newline = false;
          width = 350;
          height = 180;
          offset = "10x40";
          shrink = true;
          transparency = 0;
          idle_threshold = 120;
          monitor = 0;
          follow = "mouse";
          sticky_history = true;
          history_length = 20;
          show_indicators = true;
          line_height = 0;
          separator_height = 3;
          padding = 8;
          horizontal_padding = 10;
          separator_color = "#1d2021";
          # TODO: fix
          # dmenu = "${pkgs.rofi}/bin/rofi -dmenu -theme ~/.config/rofi/notification/action-theme.rasi -p \" \"";
          # browser = "${pkgs.firefox}/bin/firefox"; # Assuming firefox is in your environment
          icon_position = "left";
          min_icon_size = 100;
          max_icon_size = 100;
          # TODO: replace
          icon_path = "/usr/share/icons/Papirus-Dark/24x24/actions:/usr/share/icons/Papirus/24x24/animations:/usr/share/icons/Papirus/24x24/apps:/usr/share/icons/Papirus/24x24/categories:/usr/share/icons/Papirus/24x24/devices:/usr/share/icons/Papirus/24x24/emblems:/usr/share/icons/Papirus/24x24/emotes:/usr/share/icons/Papirus/24x24/mimetypes:/usr/share/icons/Papirus/24x24/panel:/usr/share/icons/Papirus/24x24/places:/usr/share/icons/Papirus/24x24/status";
          corner_radius = 10;
          progress_bar = true;
          progress_bar_height = 10;
          mouse_left_click = "close_current";
          mouse_middle_click = "close_all";
          mouse_right_click = "context";
        };
        urgency_low = {
          background = "#1E1E2E";
          foreground = "#CDD6F4";
        };
        urgency_normal = {
          background = "#1E1E2E";
          foreground = "#CDD6F4";
        };
        urgency_critical = {
          background = "#1E1E2E";
          foreground = "#CDD6F4";
          frame_color = "#FAB387";
        };
      };
    };
  };
}
