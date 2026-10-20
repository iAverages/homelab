{
  config,
  lib,
  ...
}: let
  cfg = config.networking.pihole-dns;
  servers = ["192.168.1.12"] ++ lib.optional cfg.cloudflareFallback "1.1.1.1";
in {
  options.networking.pihole-dns = {
    enable = lib.mkEnableOption "pihole-dns";
    cloudflareFallback = lib.mkEnableOption "1.1.1.1 as a fallback when the pihole is unreachable";
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      settings."global-dns-domain-*".servers = lib.concatStringsSep "," servers;
    };
    networking.nameservers = servers;
    services.resolved = {
      enable = true;
      settings.Resolve.FallbackDNS = [""];
    };
  };
}
