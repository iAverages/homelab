{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.traefik;
  monitoringEnabled = config.homelab.monitoring.prometheus-stack.enable;
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
    ip = lib.mkOption {type = types.nullOr types.str;};
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
        # service =
        # if cfg.ip != null
        # then {
        #   loadBalancerIP = cfg.ip;
        # }
        # else {};
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
          websecure =
            if cfg.ip == null
            then {nodePort = 443;}
            else {};
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
