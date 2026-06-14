{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.shiori;
in {
  options.homelab.shiori = {
    enable = lib.mkEnableOption "shiori";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "shiori." + config.homelab.domain;
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      manifests.shiori.content = [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = "shiori";
          };
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "shiori";
            namespace = "shiori";
            labels = {app = "shiori";};
          };
          spec = {
            replicas = 1;
            selector = {matchLabels = {app = "shiori";};};
            template = {
              metadata = {
                namespace = "shiori";
                labels = {app = "shiori";};
              };
              spec = {
                volumes = [
                  {
                    name = "app";
                    hostPath = {path = "/opt/kubernetes/shiori";};
                  }
                  {
                    name = "tmp";
                    emptyDir = {medium = "Memory";};
                  }
                ];
                containers = [
                  {
                    name = "shiori";
                    image = "ghcr.io/go-shiori/shiori:latest";
                    command = ["/usr/bin/shiori" "serve"];
                    imagePullPolicy = "Always";
                    ports = [{containerPort = 8080;}];
                    env = [
                      {
                        name = "SHIORI_DIR";
                        value = "/srv/shiori";
                      }
                    ];
                    volumeMounts = [
                      {
                        mountPath = "/srv/shiori";
                        name = "app";
                      }
                      {
                        mountPath = "/tmp";
                        name = "tmp";
                      }
                    ];
                  }
                ];
              };
            };
          };
        }
        {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            namespace = "shiori";
            name = "shiori";
          };
          spec = {
            type = "LoadBalancer";
            selector = {app = "shiori";};
            ports = [
              {
                port = 8080;
                targetPort = 8080;
              }
            ];
          };
        }
        {
          apiVersion = "networking.k8s.io/v1";
          kind = "Ingress";
          metadata = {
            namespace = "shiori";
            name = "shiori";
          };
          spec = {
            ingressClassName = "traefik";
            rules = [
              {
                http = {
                  host = cfg.domain;
                  paths = [
                    {
                      path = "/";
                      pathType = "Prefix";
                      backend = {
                        service = {
                          name = "shiori";
                          port = {number = 8080;};
                        };
                      };
                    }
                  ];
                };
              }
            ];
          };
        }
      ];
    };
  };
}
