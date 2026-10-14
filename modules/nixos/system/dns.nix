{
  config,
  lib,
  ...
}: let
  cfg = config.networking.cloudflare-dns;
in {
  options.networking.cloudflare-dns.enable = lib.mkEnableOption "cloudflare-dns";

  config = lib.mkIf cfg.enable {
    networking.networkmanager = {
      enable = true;
      dns = "systemd-resolved";
      settings."global-dns-domain-*".servers = "1.1.1.1";
    };
    networking.nameservers = ["1.1.1.1"];
    services.resolved = {
      enable = true;
      settings.Resolve.FallbackDNS = [""];
    };
  };
}
