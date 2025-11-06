{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.traefik;
  inherit (lib) types;
in {
  options.homelab.traefik.tls = {
    key = lib.mkOption {
      type = types.listOf lib.types.str;
    };

    crt = lib.mkOption {
      type = types.listOf lib.types.str;
    };
  };

  config.services.k3s.autoDeployCharts.traefik = {
    name = "metallb";
    repo = "https://metallb.github.io/metallb";
    version = "6.4.22";
    hash = "";
    targetNamespace = "traefik";
    createNamespace = true;

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

    values = {
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
}
