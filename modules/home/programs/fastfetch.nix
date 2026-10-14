{
  config,
  lib,
  ...
}: let
  cfg = config.programs.fastfetch;
in {
  config = lib.mkIf cfg.enable {
    programs.fastfetch = {
      settings = {
        logo = {
          type = "kitty-icat";
          # todo
          source = "/home/dan/Downloads/kita.webp";
          width = 24;
          height = 24;
        };
        display = {
          color = {
            keys = "38;2;181;137;164";
            title = "blue";
          };
          percent = {
            type = 9;
          };
          separator = " 󰁔 ";
        };
        modules = [
          "break"
          {
            type = "custom";
            outputColor = "38;2;138;56;210";
            format = "              OS Information              ";
          }
          {
            type = "title";
            key = "╭─ ";

            color = {
              user = "38;2;181;137;164";
              host = "38;2;181;137;164";
            };
          }
          {
            type = "os";
            key = "├─ ";
          }
          {
            type = "kernel";
            key = "├─ ";
          }
          {
            type = "packages";
            key = "├─ ";
          }
          {
            type = "shell";
            key = "╰─ ";
          }
          {
            type = "custom";
            outputColor = "38;2;138;56;210";
            format = "           Hardware Information           ";
          }
          {
            type = "cpu";
            key = "╭─ 󰍛";
          }
          {
            type = "gpu";
            key = "├─ ";
          }
          {
            type = "memory";
            key = "╰─ ";
          }
          "break"
        ];
      };
    };
  };
}
