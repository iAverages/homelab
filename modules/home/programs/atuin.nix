{
  config,
  lib,
  ...
}: let
  cfg = config.programs.atuin;
in {
  config = lib.mkIf cfg.enable {
    programs.atuin = {
      daemon.enable = true;
      settings = {
        sync.records = true;
        sync_frequency = "10m";
        auto_sync = true;
        sync_address = "https://atuin.dan.local";
        dialect = "uk";
        inline_height = 32;
      };
    };
  };
}
