{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.immich.db;
  inherit (lib) types;
in {
  options.homelab.immich.db = {
    instances = lib.mkOption {
      type = types.int;
      default = 1;
      description = "Number of PostgreSQL instances";
    };

    storageSize = lib.mkOption {
      type = types.str;
      default = "10Gi";
      description = "Storage size for the database";
    };

    walStorageSize = lib.mkOption {
      type = types.str;
      default = "2Gi";
      description = "WAL storage size";
    };

    backup.enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable database backups";
    };
  };

  config = lib.mkIf config.homelab.immich.enable {
    services.k3s = {
      manifests.immich-db.content =
        [
          {
            apiVersion = "networking.k8s.io/v1";
            kind = "NetworkPolicy";
            metadata = {
              name = "immich-db-allow-app";
              namespace = "immich";
            };
            spec = {
              podSelector.matchLabels."cnpg.io/cluster" = "immich-db";
              ingress = [
                {
                  from = [
                    {
                      podSelector.matchLabels."app.kubernetes.io/instance" = "immich";
                    }
                  ];
                  ports = [
                    {
                      port = 5432;
                    }
                  ];
                }
              ];
            };
          }

          {
            apiVersion = "networking.k8s.io/v1";
            kind = "NetworkPolicy";
            metadata = {
              name = "immich-db-allow-operator";
              namespace = "immich";
            };
            spec = {
              podSelector.matchLabels."cnpg.io/cluster" = "immich-db";
              ingress = [
                {
                  from = [
                    {
                      namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "cnpg-system";
                      podSelector.matchLabels."app.kubernetes.io/name" = "cloudnative-pg";
                    }
                  ];
                  ports = [
                    {port = 8000;}
                    {port = 5432;}
                  ];
                }
              ];
            };
          }

          {
            apiVersion = "networking.k8s.io/v1";
            kind = "NetworkPolicy";
            metadata = {
              name = "immich-db-allow-monitoring";
              namespace = "immich";
            };
            spec = {
              podSelector.matchLabels."cnpg.io/cluster" = "immich-db";
              ingress = [
                {
                  from = [
                    {
                      namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "monitoring";
                      podSelector.matchLabels."app.kubernetes.io/name" = "prometheus";
                    }
                  ];
                  ports = [
                    {
                      port = 9187;
                    }
                  ];
                }
              ];
            };
          }

          {
            apiVersion = "networking.k8s.io/v1";
            kind = "NetworkPolicy";
            metadata = {
              name = "immich-db-allow-inter-node";
              namespace = "immich";
            };
            spec = {
              podSelector.matchLabels."cnpg.io/cluster" = "immich-db";
              ingress = [
                {
                  from = [
                    {
                      podSelector.matchLabels."cnpg.io/cluster" = "immich-db";
                    }
                  ];
                  ports = [
                    {
                      port = 5432;
                    }
                  ];
                }
              ];
            };
          }

          {
            apiVersion = "postgresql.cnpg.io/v1";
            kind = "Cluster";
            metadata = {
              name = "immich-db";
              namespace = "immich";
            };
            spec =
              {
                inherit (cfg) instances;
                minSyncReplicas = 0;
                maxSyncReplicas = 0;

                imageName = "ghcr.io/tensorchord/cloudnative-vectorchord:16.9-0.4.3";
                postgresql = {
                  shared_preload_libraries = ["vchord.so"];
                };

                bootstrap = {
                  initdb = {
                    postInitApplicationSQL = [
                      "CREATE EXTENSION vchord CASCADE;"
                      "CREATE EXTENSION earthdistance CASCADE;"
                    ];
                  };
                };

                monitoring = {
                  enablePodMonitor = true;
                };

                storage = {
                  storageClass = "local-path";
                  resizeInUseVolumes = false;
                  size = cfg.storageSize;
                };

                walStorage = {
                  storageClass = "local-path";
                  resizeInUseVolumes = false;
                  size = cfg.walStorageSize;
                };

                resources = {
                  requests = {
                    memory = "128Mi";
                  };
                  limits.memory = "512Mi";
                };
              }
              // lib.optionalAttrs cfg.backup.enable {
                backup = {
                  barmanObjectStore = {
                    destinationPath = "s3://immich-backup";
                    endpointURL = "https://s3.${config.homelab.garage.domain}";
                    s3Credentials = {
                      accessKeyId = {
                        name = "immich-db-backup-s3-credentials";
                        key = "access-key-id";
                      };
                      secretAccessKey = {
                        name = "immich-db-backup-s3-credentials";
                        key = "secret-access-key";
                      };
                    };
                    data.compression = "snappy";
                    wal.compression = "snappy";
                  };

                  retentionPolicy = "30d";
                };
              };
          }
        ]
        ++ lib.optionals cfg.backup.enable [
          {
            apiVersion = "rbac.authorization.k8s.io/v1";
            kind = "Role";
            metadata = {
              name = "immich-db";
              namespace = "immich";
            };
            rules = [
              {
                apiGroups = [""];
                resources = ["secrets"];
                resourceNames = ["immich-db-backup-s3-credentials"];
                verbs = ["get"];
              }
              {
                apiGroups = ["postgresql.cnpg.io"];
                resources = ["backups"];
                verbs = [
                  "get"
                  "list"
                  "watch"
                  "patch"
                  "update"
                ];
              }
              {
                apiGroups = ["postgresql.cnpg.io"];
                resources = ["backups/status"];
                verbs = [
                  "get"
                  "patch"
                  "update"
                ];
              }
            ];
          }

          {
            apiVersion = "rbac.authorization.k8s.io/v1";
            kind = "RoleBinding";
            metadata = {
              name = "immich-db";
              namespace = "immich";
            };
            roleRef = {
              apiGroup = "rbac.authorization.k8s.io";
              kind = "Role";
              name = "immich-db";
            };
            subjects = [
              {
                kind = "ServiceAccount";
                name = "immich-db";
                namespace = "immich";
              }
            ];
          }

          {
            apiVersion = "postgresql.cnpg.io/v1";
            kind = "ScheduledBackup";
            metadata = {
              name = "immich-db";
              namespace = "immich";
            };
            spec = {
              schedule = "0 0 1 * * 0";
              immediate = true;
              backupOwnerReference = "self";
              cluster.name = "immich-db";
            };
          }
        ];
    };
  };
}
