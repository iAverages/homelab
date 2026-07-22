{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.traefik;
  monitoringEnabled = config.homelab.monitoring.prometheus-stack.enable;
  cloudflareSourceRanges = [
    # BEGIN CLOUDFLARE SOURCE RANGES
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
    # END CLOUDFLARE SOURCE RANGES
  ];
  inherit (lib) types;
in {
  options.homelab.traefik = {
    tls = {
      crt = lib.mkOption {type = types.str;};
      key = lib.mkOption {type = types.str;};
    };
    domain = lib.mkOption {
      type = types.nullOr types.str;
      default =
        if config.homelab.domain != null
        then "traefik.${config.homelab.domain}"
        else null;
    };
    ip = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    cloudflareOnly = lib.mkEnableOption "restricting public Traefik load balancer traffic to Cloudflare IP ranges";
  };

  config.services.k3s = lib.mkIf config.homelab.enable {
    # needs to be called traefik-helm as k3s tried to write to the same file
    autoDeployCharts.traefik-helm = {
      name = "traefik";
      repo = "https://traefik.github.io/charts";
      version = "37.2.0";
      hash = "sha256-AEncqkz0Rei7/+b7SiEHeKX2xRmAbF6Zu1n6Ob2NB80=";
      targetNamespace = "traefik";
      createNamespace = true;

      values = {
        service =
          lib.optionalAttrs (cfg.ip != null) {
            loadBalancerIP = cfg.ip;
          }
          // lib.optionalAttrs cfg.cloudflareOnly {
            loadBalancerSourceRanges = cloudflareSourceRanges;
          };
        ingressRoute =
          if cfg.domain != null
          then {
            dashboard = {
              enabled = true;
              matchRule = "Host(`${cfg.domain}`)";
              entryPoints = ["websecure"];
            };
          }
          else {};

        ports = {
          web = {
            redirections = {
              entryPoint = {
                to = "websecure";
                scheme = "https";
                permanent = true;
              };
            };
          };
        };
        metrics =
          if monitoringEnabled
          then {
            prometheus = {
              service = {
                enabled = true;
              };
              serviceMonitor = {
                enabled = true;
              };
            };
          }
          else {};
        ingressClass = {
          name = "traefik";
        };
        providers = {
          kubernetesCRD = {
            ingressClass = "traefik";
          };
          kubernetesIngress = {
            ingressClass = "traefik";
          };
        };
        tlsStore = {
          default = {
            defaultCertificate = {
              secretName = "traefik-cert";
            };
          };
        };
      };
    };

    secrets = [
      {
        metadata = {
          name = "traefik-cert";
          namespace = "traefik";
        };
        stringData = {
          "tls.crt" = cfg.tls.crt;
          "tls.key" = cfg.tls.key;
        };
      }
    ];
  };
}
