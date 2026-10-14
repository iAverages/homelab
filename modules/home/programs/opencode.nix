{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  cfg = config.programs.opencode;
in {
  config = lib.mkIf cfg.enable {
    programs.opencode.package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  };
}
