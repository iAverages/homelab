{options, ...}: {
  services.timesyncd.enable = true;
  networking.timeServers = options.networking.timeServers.default ++ ["time.cloudflare.com"];
}
