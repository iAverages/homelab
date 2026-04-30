{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.immich;
in {
  imports = [
    ./db.nix
  ];

  options.homelab.immich = {
    enable = lib.mkEnableOption "immich";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "immich.${config.homelab.domain}";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      autoDeployCharts.immich = {
        name = "immich";
        repo = "oci://ghcr.io/immich-app/immich-charts/immich";
        version = "0.11.1";
        hash = "sha256-TiMy4nPuNnF2tb3Y+wwXofYEYqigWswuSo6po6LmnXY=";
        targetNamespace = "immich";
        createNamespace = true;

        values = {
          resources = {
            requests = {
              memory = "1.6Gi";
            };
            limits.memory = "2.5Gi";
          };

          replicaCount = 1;

          server = {
            ingress = {
              main = {
                enabled = true;
                hosts = [
                  {
                    host = cfg.domain;
                    paths = [
                      {
                        path = "/";
                        service = {
                          identifier = "main";
                        };
                      }
                    ];
                  }
                ];
              };
            };
          };

          controllers = {
            main = {
              containers = {
                main = {
                  env = {
                    # REDIS_URL = "redis://immich-dragonfly.immich.svc.cluster.local:6379";
                    REDIS_HOSTNAME = "immich-dragonfly.immich.svc.cluster.local";
                    REDIS_PORT = "6379";
                    DB_HOSTNAME = {
                      valueFrom.secretKeyRef = {
                        name = "immich-db-app";
                        key = "host";
                      };
                    };

                    DB_USERNAME = {
                      valueFrom.secretKeyRef = {
                        name = "immich-db-app";
                        key = "username";
                      };
                    };

                    DB_PASSWORD = {
                      valueFrom.secretKeyRef = {
                        name = "immich-db-app";
                        key = "password";
                      };
                    };

                    DB_DATABASE_NAME = {
                      valueFrom.secretKeyRef = {
                        name = "immich-db-app";
                        key = "dbname";
                      };
                    };
                  };
                };
              };
            };
          };

          immich = {
            metrics.enabled = true;
            persistence = {
              enable = true;
              library.existingClaim = "immich-pvc";
            };
          };
        };
      };

      manifests = {
        immich-dragonfly.content = {
          apiVersion = "dragonflydb.io/v1alpha1";
          kind = "Dragonfly";
          metadata = {
            name = "immich-dragonfly";
            namespace = "immich";
          };
          spec = {
            replicas = 1;
            args = [
              "--proactor_threads=1"
              "--default_lua_flags=allow-undeclared-keys"
            ];
            resources = {
              requests = {
                cpu = "50m";
                memory = "256Mi";
              };
              limits = {
                memory = "384Mi";
              };
            };
          };
        };
        immich-pv.content = [
          {
            apiVersion = "v1";
            kind = "PersistentVolume";
            metadata = {
              name = "immich-pv";
              namespace = "immich";
            };
            spec = {
              capacity = {
                storage = "100Gi";
              };
              accessModes = ["ReadWriteOnce"];
              storageClassName = "local-path";
              persistentVolumeReclaimPolicy = "Retain";
              hostPath = {
                path = "/opt/kubernetes/immich";
                type = "DirectoryOrCreate";
              };
            };
          }
        ];

        immich-pvc.content = [
          {
            apiVersion = "v1";
            kind = "PersistentVolumeClaim";
            metadata = {
              name = "immich-pvc";
              namespace = "immich";
            };
            spec = {
              accessModes = ["ReadWriteOnce"];
              storageClassName = "local-path";
              resources = {
                requests = {
                  storage = "100Gi";
                };
              };
              volumeName = "immich-pv";
            };
          }
        ];
      };
    };
  };
}
