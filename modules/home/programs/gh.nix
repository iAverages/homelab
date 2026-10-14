{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.gh;
in {
  config = lib.mkIf cfg.enable {
    programs.gh.settings = {
      version = 1;
      git_protocol = "ssh";
      editor = lib.getExe pkgs.neovim;
      prompt = "enabled";
      pager = lib.getExe pkgs.delta;
      aliases = {
        co = "pr checkout";
        opr = "pr view --web";
      };
      http_unix_socket = "";
      browser = "";
    };
  };
}
