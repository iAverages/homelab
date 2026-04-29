{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.forgejo;
  inherit (lib) types;
in {
  imports = [
    ./db.nix
    # ./runner.nix
  ];

  options.homelab.forgejo = {
    enable = lib.mkEnableOption "forgejo";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "git.${config.homelab.domain}";
    };

    admin = {
      username = lib.mkOption {
        type = types.str;
      };
      password = lib.mkOption {
        type = types.str;
      };
      email = lib.mkOption {
        type = types.str;
      };
    };

    runners = lib.mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            token = lib.mkOption {
              type = types.str;
            };
            name = lib.mkOption {
              type = types.str;
            };
            labels = lib.mkOption {
              type = types.listOf types.str;
            };
            replicas = lib.mkOption {
              type = types.int;
              default = 1;
            };
          };
        }
      );
      default = [];
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      autoDeployCharts.forgejo = {
        name = "forgejo";
        repo = "oci://code.forgejo.org/forgejo-helm/forgejo";
        version = "17.0.1";
        hash = "sha256-OpwFx2Cr9izPaiwC8l84Opi6LjIe/rnaxNE+7fyuFpE=";
        targetNamespace = "forgejo";
        createNamespace = true;

        values = {
          resources = {
            requests = {
              memory = "1.6Gi";
            };
            limits.memory = "2.5Gi";
          };

          replicaCount = 1;

          service = {
            ssh = {
              type = "NodePort";
              nodePort = 30988;
            };
            http = {
              type = "ClusterIP";
            };
          };

          ingress = {
            enabled = true;
            className = "traefik";
            hosts = [
              {
                host = cfg.domain;
                paths = [
                  {
                    path = "/";
                    port = "http";
                    pathType = "Prefix";
                  }
                ];
              }
            ];
          };

          persistence = {
            enabled = true;
            create = true;
            mount = true;
            claimName = "gitea-shared-storage";
            size = "1Gi";
            accessModes = ["ReadWriteOnce"];
            labels = {};
            storageClass = null;
            subPath = null;
            volumeName = "";
            annotations = {
              "helm.sh/resource-policy" = "keep";
            };
          };

          signing = {
            enabled = false;
          };

          gitea = {
            admin = {
              existingSecret = "forgejo-admin";
              inherit (cfg.admin) email;
              passwordMode = "keepUpdated";
            };
            metrics.enabled = true;

            additionalConfigFromEnvs = [
              {
                name = "FORGEJO__server__DOMAIN";
                value = cfg.domain;
              }
              {
                name = "FORGEJO__server__ROOT_URL";
                value = "https://${cfg.domain}/";
              }
              {
                name = "FORGEJO__server__PROTOCOL";
                value = "http";
              }
              {
                name = "FORGEJO__database__DB_TYPE";
                value = "postgres";
              }
              {
                name = "FORGEJO__database__HOST";
                valueFrom.secretKeyRef = {
                  name = "forgejo-db-app";
                  key = "host";
                };
              }
              {
                name = "FORGEJO__database__NAME";
                valueFrom.secretKeyRef = {
                  name = "forgejo-db-app";
                  key = "dbname";
                };
              }
              {
                name = "FORGEJO__database__USER";
                valueFrom.secretKeyRef = {
                  name = "forgejo-db-app";
                  key = "username";
                };
              }
              {
                name = "FORGEJO__database__PASSWD";
                valueFrom.secretKeyRef = {
                  name = "forgejo-db-app";
                  key = "password";
                };
              }

              {
                name = "FORGEJO__storage__STORAGE_TYPE";
                value = "minio";
              }
              {
                name = "FORGEJO__storage__MINIO_ENDPOINT";
                valueFrom.secretKeyRef = {
                  name = "forgejo-s3-credentials";
                  key = "host";
                };
              }
              {
                name = "FORGEJO__storage__MINIO_LOCATION";
                valueFrom.secretKeyRef = {
                  name = "forgejo-s3-credentials";
                  key = "region";
                };
              }
              {
                name = "FORGEJO__storage__MINIO_ACCESS_KEY_ID";
                valueFrom.secretKeyRef = {
                  name = "forgejo-s3-credentials";
                  key = "access-key-id";
                };
              }
              {
                name = "FORGEJO__storage__MINIO_SECRET_ACCESS_KEY";
                valueFrom.secretKeyRef = {
                  name = "forgejo-s3-credentials";
                  key = "secret-access-key";
                };
              }
              {
                name = "FORGEJO__storage__MINIO_BUCKET";
                value = "forgejo-bucket";
              }
              {
                name = "FORGEJO__storage__MINIO_USE_SSL";
                value = "false";
              }
              {
                name = "FORGEJO__storage__MINIO_FORCE_PATH_STYLE";
                value = "true";
              }
            ];

            ssh = {
              logLevel = "INFO";
            };

            config = {
              server = {
                SSH_PORT = 30988;
                DOMAIN = cfg.domain;
                ROOT_URL = "https://${cfg.domain}/";
                PROTOCOL = "http";
              };
              APP_NAME = "Forgejo: Beyond coding. We forge.";
              RUN_MODE = "prod";

              service = {
                DEFAULT_ALLOW_CREATE_ORGANIZATION = false;
              };
              repository = {
                MAX_CREATION_LIMIT = 0;
              };

              queue = {
                TYPE = "redis";
                CONN_STR = "redis://forgejo-dragonfly.forgejo.svc.cluster.local:6379";
              };
              cache = {
                ADAPTER = "redis";
                HOST = "redis://forgejo-dragonfly.forgejo.svc.cluster.local:6379";
              };
              session = {
                PROVIDER = "redis";
                PROVIDER_CONFIG = "redis://forgejo-dragonfly.forgejo.svc.cluster.local:6379";
              };
            };
          };
        };
      };

      manifests.forgejo-dragonfly.content = {
        apiVersion = "dragonflydb.io/v1alpha1";
        kind = "Dragonfly";
        metadata = {
          name = "forgejo-dragonfly";
          namespace = "forgejo";
        };
        spec = {
          replicas = 1;
          args = [
            "--proactor_threads=1"
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

      manifests = {
        forgejo-bucket.content = {
          apiVersion = "garage.rajsingh.info/v1alpha1";
          kind = "GarageBucket";
          metadata = {
            name = "forgejo-bucket";
            namespace = "forgejo";
          };
          spec = {
            clusterRef = {
              name = "garage";
              namespace = "garage";
            };
            quotas.maxSize = "50Gi";
          };
        };

        forgejo-s3-credentials.content = {
          apiVersion = "garage.rajsingh.info/v1alpha1";
          kind = "GarageKey";
          metadata = {
            name = "forgejo-s3-credentials";
            namespace = "forgejo";
          };
          spec = {
            clusterRef = {
              name = "garage";
              namespace = "garage";
            };
            bucketPermissions = [
              {
                bucketRef = "forgejo-bucket";
                read = true;
                write = true;

                # Forgejo requires owner permissions for the BucketExists() check during initialization.
                # This is only needed at startup; normal operations only use read/write permissions.
                owner = true;
              }
            ];
          };
        };
      };

      secrets = let
        runnerSecrets =
          map (runner: {
            metadata = {
              name = "forgejo-runner-${runner.name}";
              namespace = "forgejo";
            };
            stringData = {
              CONFIG_TOKEN = runner.token;
              CONFIG_NAME = runner.name;
              CONFIG_INSTANCE = "https://${cfg.ingressHost}";
            };
          })
          cfg.runners;
      in
        [
          {
            metadata = {
              name = "forgejo-admin";
              namespace = "forgejo";
            };
            stringData = {
              inherit (cfg.admin) username;
              inherit (cfg.admin) password;
            };
          }
        ]
        ++ runnerSecrets;
    };
  };
}
