{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.virtualisation.docker;
in {
  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      package = pkgs.docker_29;
      enableOnBoot = true;
      autoPrune.enable = true;
      liveRestore = false;
      extraOptions = "--insecure-registry=\"ctr.dan.local\"";
    };
    users.users.dan.extraGroups = ["docker"];
    environment.systemPackages = with pkgs; [
      docker
      dive
    ];
  };
}
