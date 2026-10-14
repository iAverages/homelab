{
  config,
  lib,
  ...
}: let
  cfg = config.programs.direnv;
in {
  config = lib.mkIf cfg.enable {
    programs.direnv = {
      silent = true;
      nix-direnv.enable = true;
    };
  };
}
