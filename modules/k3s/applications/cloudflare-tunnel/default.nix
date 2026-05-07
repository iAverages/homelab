{
  pkgs,
  config,
  lib,
  ...
}: let
  toYamlString = value:
    builtins.readFile ((pkgs.formats.yaml {}).generate "config.yaml" value);

  cfg = config.homelab.cloudflare-tunnel;
  inherit (lib) types;
in {
  options.homelab.cloudflare-tunnel = {
    enable = lib.mkEnableOption "cloudflare-tunnel";
    secretsConfig = lib.mkOption {type = types.str;};
    tunnelName = lib.mkOption {type = types.str;};
    ingress = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          hostname = lib.mkOption {
            type = types.str;
            description = "Hostname to match.";
          };

          service = lib.mkOption {
            type = types.str;
            description = "Backend service URL.";
          };
        };
      });
      default = [];
      example = [
        {
          hostname = "grafana.example.com";
          service = "http://prom-stack-grafana.monitoring.svc.cluster.local:80";
        }
        {
          hostname = "argocd.example.com";
          service = "http://argocd-server.argocd.svc.cluster.local:80";
        }
      ];
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    manifests = {
      cloudflare-tunnel.content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "cloudflare-tunnel";
        };
      };

      cloudflare-tunnel-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "cloudflared";
          namespace = "cloudflare-tunnel";
        };
        spec = {
          selector = {
            matchLabels = {
              app = "cloudflared";
            };
          };
          replicas = 2;
          template = {
            metadata = {
              labels = {
                app = "cloudflared";
              };
            };
            spec = {
              containers = [
                {
                  name = "cloudflared";
                  image = "cloudflare/cloudflared:2026.3.0";
                  args = [
                    "tunnel"
                    "--config"
                    "/etc/cloudflared/config/config.yaml"
                    "run"
                  ];
                  livenessProbe = {
                    httpGet = {
                      path = "/ready";
                      port = 2000;
                    };
                    failureThreshold = 1;
                    initialDelaySeconds = 10;
                    periodSeconds = 10;
                  };
                  volumeMounts = [
                    {
                      name = "config";
                      mountPath = "/etc/cloudflared/config";
                      readOnly = true;
                    }
                    {
                      name = "creds";
                      mountPath = "/etc/cloudflared/creds";
                      readOnly = true;
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "creds";
                  secret = {
                    secretName = "cloudflare-tunnel-secret";
                  };
                }
                {
                  name = "config";
                  configMap = {
                    name = "cloudflared";
                    items = [
                      {
                        key = "config.yaml";
                        path = "config.yaml";
                      }
                    ];
                  };
                }
              ];
            };
          };
        };
      };

      cloudflare-tunnel-configmap.content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "cloudflared";
          namespace = "cloudflare-tunnel";
        };

        data."config.yaml" = toYamlString {
          tunnel = cfg.tunnelName;
          credentials-file = "/etc/cloudflared/creds/credentials.json";
          metrics = "0.0.0.0:2000";
          no-autoupdate = true;
          protocol = "http2";
          ingress =
            cfg.ingress
            ++ [
              {
                service = "http_status:404";
              }
            ];
        };
      };
    };

    secrets = [
      {
        metadata = {
          name = "cloudflare-tunnel-secret";
          namespace = "cloudflare-tunnel";
        };
        stringData = {
          "credentials.json" = cfg.secretsConfig;
        };
      }
    ];
  };
}
