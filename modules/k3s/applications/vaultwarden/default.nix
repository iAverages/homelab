{
  lib,
  config,
  ...
}: let
  inherit (lib) types;
  cfg = config.homelab.vaultwarden;
in {
  options.homelab.vaultwarden = {
    enable = lib.mkEnableOption "vaultwarden";
    domain = lib.mkOption {
      type = types.nullOr types.str;
      default =
        if config.homelab.domain != null
        then "warden.${config.homelab.domain}"
        else null;
    };
    backup.enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable database backups";
    };
    pushNotifications = {
      installationId = lib.mkOption {
        type = types.str;
      };
      installationKey = lib.mkOption {
        type = types.str;
      };
    };
    smtp = {
      from = lib.mkOption {
        type = types.str;
      };
      host = lib.mkOption {
        type = types.str;
      };
      port = lib.mkOption {
        type = types.str;
      };
      username = lib.mkOption {
        type = types.str;
      };
      password = lib.mkOption {
        type = types.str;
      };
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.vaultwarden = {
      name = "vaultwarden";
      repo = "https://guerzon.github.io/vaultwarden";
      version = "0.34.4";
      hash = "sha256-qn2kfuXoLqHLyacYrBwvKgVb+qZjMu+E16dq9jJS3RE=";
      targetNamespace = "vaultwarden";
      createNamespace = true;

      values = {
        serviceAccount = {
          create = true;
          name = "vaultwarden-svc";
        };

        webVaultEnabled = true;

        database = {
          type = "postgresql";
          existingSecret = "vaultwarden-db-app";
          existingSecretKey = "uri";
        };

        pushNotifications = {
          enabled = true;
          existingSecret = "vaultwarden-secrets";
          installationId.existingSecretKey = "pushNotificationsInstallationId";
          installationKey.existingSecretKey = "pushNotificationsInstallationKey";
        };

        domain =
          if cfg.domain != null
          then "https://${cfg.domain}"
          else "";

        smtp = {
          existingSecret = "vaultwarden-secrets";
          from = cfg.smtp.from;
          host = cfg.smtp.host;
          username = {
            existingSecretKey = "smtpUsername";
          };
          password = {
            existingSecretKey = "smtpPassword";
          };
        };

        ingress =
          if cfg.domain != null
          then {
            enabled = true;
            class = "traefik";
            hostname = cfg.domain;
          }
          else {};
      };
      extraDeploy =
        [
          {
            apiVersion = "postgresql.cnpg.io/v1";
            kind = "Cluster";
            metadata = {
              name = "vaultwarden-db";
              namespace = "vaultwarden";
            };
            spec =
              {
                instances = 1;
                storage = {size = "5Gi";};
              }
              // lib.optionalAttrs cfg.backup.enable {
                backup = {
                  barmanObjectStore = {
                    destinationPath = "s3://vaultwarden-backup";
                    endpointURL = "https://s3.${config.homelab.garage.domain}";
                    s3Credentials = {
                      accessKeyId = {
                        name = "vaultwarden-db-backup-s3-credentials";
                        key = "access-key-id";
                      };
                      secretAccessKey = {
                        name = "vaultwarden-db-backup-s3-credentials";
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
              name = "vaultwarden-db";
              namespace = "vaultwarden";
            };
            rules = [
              {
                apiGroups = [""];
                resources = ["secrets"];
                resourceNames = ["vaultwarden-db-backup-s3-credentials"];
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
              name = "vaultwarden-db";
              namespace = "vaultwarden";
            };
            roleRef = {
              apiGroup = "rbac.authorization.k8s.io";
              kind = "Role";
              name = "vaultwarden-db";
            };
            subjects = [
              {
                kind = "ServiceAccount";
                name = "vaultwarden-db";
                namespace = "vaultwarden";
              }
            ];
          }

          {
            apiVersion = "postgresql.cnpg.io/v1";
            kind = "ScheduledBackup";
            metadata = {
              name = "vaultwarden-db";
              namespace = "vaultwarden";
            };
            spec = {
              schedule = "0 0 1 * * 0";
              immediate = true;
              backupOwnerReference = "self";
              cluster.name = "vaultwarden-db";
            };
          }
        ];
    };
    secrets = [
      {
        metadata = {
          name = "vaultwarden-secrets";
          namespace = "vaultwarden";
        };
        stringData = {
          smtpUsername = cfg.smtp.username;
          smtpPassword = cfg.smtp.password;
          pushNotificationsInstallationId = cfg.pushNotifications.installationId;
          pushNotificationsInstallationKey = cfg.pushNotifications.installationKey;
        };
      }
    ];
  };
}
