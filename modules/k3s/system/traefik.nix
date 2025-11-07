{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.traefik;
  inherit (lib) types;
in {
  options.homelab.traefik.tls = {
    crt = lib.mkOption {type = types.path;};
    key = lib.mkOption {type = types.path;};
    domain = lib.mkOption {type = types.str;};
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
        ingressRoute = {
          dashboard = {
            enabled = true;
            matchRule = "Host(`traefik.dan.local`)";
            entryPoints = ["websecure"];
          };
        };
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
        metrics = {
          prometheus = {
            service = {
              enabled = true;
            };
            serviceMonitor = {
              enabled = true;
            };
          };
        };
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
              secretName = "dan-local-cert";
            };
          };
        };
      };
    };

    secrets = [
      {
        name = "dan-local-cert";
        namespace = "traefik";
        data = {
          "tls.crt" = cfg.tls.crt;
          "tls.key" = cfg.tls.key;
        };
      }
    ];
  };
}
