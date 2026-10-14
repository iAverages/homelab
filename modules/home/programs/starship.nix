{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.starship;
  toml = pkgs.formats.toml {};
in {
  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.starship-jj];

    home.file.".config/starship-jj/starship-jj.toml".source = toml.generate "starship-jj" {
      module_separator = " ";

      bookmarks = {
        exclude = [];
      };

      module = [
        {
          type = "Bookmarks";
          separator = " ";
          color = "Magenta";
          behind_symbol = "⇡";
          max_length = 20;
        }
        {
          type = "State";
          separator = " ";
          conflict = {
            text = "(CONFLICT)";
            color = "Red";
          };
          divergent = {
            text = "(DIVERGENT)";
            color = "Cyan";
          };
          hidden = {
            text = "(HIDDEN)";
            color = "Yellow";
          };
          immutable = {
            disabled = false;
            text = "(IMMUTABLE)";
            color = "Yellow";
          };
          empty = {
            disabled = false;
            text = "(EMPTY)";
            color = "Yellow";
          };
          added_lines = {
            prefix = "+";
            color = "Green";
          };
          removed_lines = {
            prefix = "-";
            color = "Red";
          };
        }
      ];
    };

    programs.starship = {
      settings = {
        add_newline = false;
        format = lib.concatStrings [
          "$directory"
          "\${custom.jj}"
          "$character"
        ];
        directory = {
          style = "fg:#8a38d2 bold";
          fish_style_pwd_dir_length = 1;
          truncate_to_repo = true;
        };
        character = {
          success_symbol = "[❯](fg:#6d28a5 )";
          error_symbol = "[❯](red)";
        };
        git_branch = {
          disabled = true;
          symbol = " ";
          format = "([$symbol$branch]($style)) ";
          style = "fg:#b887e4";
        };
        custom.jj = {
          command = "prompt";
          format = "$output";
          ignore_timeout = true;
          shell = ["starship-jj" "--ignore-working-copy" "starship"];
          use_stdin = false;
          when = true;
        };

        custom.git_branch = {
          when = "! jj --ignore-working-copy root";
          command = "starship module git_branch";
          description = "Only show git_branch if we're not in a jj repo";
          style = "";
        };
      };
    };
  };
}
