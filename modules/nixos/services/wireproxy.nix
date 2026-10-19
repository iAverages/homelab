{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.wireproxy;
  secret = name: config.sops.placeholder."wireproxy/${name}";
in {
  options.services.wireproxy = {
    enable = lib.mkEnableOption "wireproxy http proxy over wireguard";
    package = lib.mkPackageOption pkgs "wireproxy" {};
    port = lib.mkOption {
      type = lib.types.port;
      default = 3128;
    };
    dns = lib.mkOption {
      type = lib.types.str;
      default = "1.1.1.1";
      description = "DNS server queried through the tunnel";
    };
    tailscaleService = lib.mkOption {
      type = lib.types.str;
      default = "proxy";
      description = "Tailscale service exposing the proxy over https on port 443";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = lib.genAttrs (map (n: "wireproxy/${n}") [
      "privateKey"
      "address"
      "peerPublicKey"
      "endpoint"
      "username"
      "password"
    ]) (_: {restartUnits = ["wireproxy.service"];});

    sops.templates."wireproxy.conf" = {
      restartUnits = ["wireproxy.service"];
      content = ''
        [Interface]
        PrivateKey = ${secret "privateKey"}
        Address = ${secret "address"}
        DNS = ${cfg.dns}

        [Peer]
        PublicKey = ${secret "peerPublicKey"}
        Endpoint = ${secret "endpoint"}
        AllowedIPs = 0.0.0.0/0, ::/0
        PersistentKeepalive = 25

        [http]
        BindAddress = 127.0.0.1:${toString cfg.port}
        Username = ${secret "username"}
        Password = ${secret "password"}
      '';
    };

    systemd.services.wireproxy = {
      description = "wireproxy http proxy over wireguard";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} -c \${CREDENTIALS_DIRECTORY}/config";
        LoadCredential = "config:${config.sops.templates."wireproxy.conf".path}";
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "10s";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
      };
    };

    services.tailscale.enable = true;

    # tailscale terminates tls so clients get a trusted ts.net cert
    systemd.services.wireproxy-tailscale = {
      description = "Expose wireproxy through Tailscale";
      after = ["wireproxy.service" "tailscaled-autoconnect.service"];
      requires = ["wireproxy.service"];
      wants = ["tailscaled.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe config.services.tailscale.package} serve --yes --service=svc:${cfg.tailscaleService} --tls-terminated-tcp=443 tcp://127.0.0.1:${toString cfg.port}";
        ExecStop = "${lib.getExe config.services.tailscale.package} serve drain svc:${cfg.tailscaleService}";
      };
    };
  };
}
