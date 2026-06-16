{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.home-assistant;
in {
  options.homelab.home-assistant = {
    enable = lib.mkEnableOption "home-assistant";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "home.${config.homelab.domain}";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      manifests.home-assistant.content = [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata = {
            name = "home-assistant";
          };
        }
        {
          apiVersion = "v1";
          kind = "PersistentVolumeClaim";
          metadata = {
            name = "home-assistant-config";
            namespace = "home-assistant";
          };
          spec = {
            accessModes = ["ReadWriteOnce"];
            storageClassName = "local-path";
            resources = {requests = {storage = "20Gi";};};
          };
        }
        {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "home-assistant-config";
            namespace = "home-assistant";
          };
          data = {
            "configuration.yaml" = ''
              default_config:

              frontend:
                themes: !include_dir_merge_named themes

              automation: !include automations.yaml
              script: !include scripts.yaml
              scene: !include scenes.yaml

              http:
                use_x_forwarded_for: true
                trusted_proxies:
                  - 10.10.0.0/16
                  - 10.42.0.0/16
                  - 10.43.0.0/16
            '';
          };
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "home-assistant";
            namespace = "home-assistant";
            labels = {"app.kubernetes.io/name" = "home-assistant";};
          };
          spec = {
            replicas = 1;
            strategy = {type = "Recreate";};
            selector = {matchLabels = {"app.kubernetes.io/name" = "home-assistant";};};
            template = {
              metadata = {labels = {"app.kubernetes.io/name" = "home-assistant";};};
              spec = {
                hostNetwork = true;
                dnsPolicy = "ClusterFirstWithHostNet";
                initContainers = [
                  {
                    name = "init-config";
                    image = "busybox:1.36";
                    command = [
                      "/bin/sh"
                      "-c"
                      "cp /defaults/configuration.yaml /config/configuration.yaml && touch /config/automations.yaml /config/scripts.yaml /config/scenes.yaml && mkdir -p /config/themes"
                    ];
                    volumeMounts = [
                      {
                        name = "config";
                        mountPath = "/config";
                      }
                      {
                        name = "initial-config";
                        mountPath = "/defaults";
                      }
                    ];
                  }
                ];
                containers = [
                  {
                    name = "home-assistant";
                    image = "ghcr.io/home-assistant/home-assistant:stable";
                    imagePullPolicy = "Always";
                    securityContext = {capabilities = {add = ["NET_ADMIN" "NET_RAW"];};};
                    ports = [
                      {
                        name = "http";
                        containerPort = 8123;
                      }
                    ];
                    env = [
                      {
                        name = "TZ";
                        value = "Europe/London";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "config";
                        mountPath = "/config";
                      }
                      {
                        name = "dbus";
                        mountPath = "/run/dbus";
                        readOnly = true;
                      }
                    ];
                  }
                ];
                volumes = [
                  {
                    name = "config";
                    persistentVolumeClaim = {claimName = "home-assistant-config";};
                  }
                  {
                    name = "initial-config";
                    configMap = {name = "home-assistant-config";};
                  }
                  {
                    name = "dbus";
                    hostPath = {
                      path = "/run/dbus";
                      type = "Directory";
                    };
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
            name = "home-assistant";
            namespace = "home-assistant";
          };
          spec = {
            selector = {"app.kubernetes.io/name" = "home-assistant";};
            ports = [
              {
                name = "http";
                port = 8123;
                targetPort = "http";
              }
            ];
          };
        }
        {
          apiVersion = "networking.k8s.io/v1";
          kind = "Ingress";
          metadata = {
            name = "home-assistant";
            namespace = "home-assistant";
          };
          spec = {
            ingressClassName = "traefik";
            rules = [
              {
                host = cfg.domain;
                http = {
                  paths = [
                    {
                      path = "/";
                      pathType = "Prefix";
                      backend = {
                        service = {
                          name = "home-assistant";
                          port = {number = 8123;};
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
