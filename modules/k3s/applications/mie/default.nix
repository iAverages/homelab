{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.mie;
in {
  options.homelab.mie = {
    enable = lib.mkEnableOption "mie";
    dockerImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/iaverages/mie@sha256:6b944e4550d51744be1db87aa23adaecc1aad702ca2246e49b1210afe3d20fcb";
    };
    b2 = {
      url = lib.mkOption {
        type = lib.types.str;
      };
      bucketId = lib.mkOption {
        type = lib.types.str;
      };
      bucketPathPrefix = lib.mkOption {
        type = lib.types.str;
      };
      bucketName = lib.mkOption {
        type = lib.types.str;
      };
      keyId = lib.mkOption {
        type = lib.types.str;
      };
      applicationKey = lib.mkOption {
        type = lib.types.str;
      };
    };
    discordToken = lib.mkOption {
      type = lib.types.str;
    };
    cdnUrl = lib.mkOption {
      type = lib.types.str;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    manifests = {
      mie-namespace.content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "mie";
        };
      };

      mie-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "mie";
          namespace = "mie";
          labels = {app = "mie";};
        };
        spec = {
          replicas = 1;
          selector = {matchLabels = {app = "mie";};};
          strategy = {
            type = "RollingUpdate";
            rollingUpdate = {
              maxUnavailable = 0;
              maxSurge = 1;
            };
          };
          template = {
            metadata = {labels = {app = "mie";};};
            spec = {
              containers = [
                {
                  name = "mie";
                  image = cfg.dockerImage;
                  imagePullPolicy = "Always";
                  env = [
                    {
                      name = "CDN_URL";
                      value = cfg.cdnUrl;
                    }
                    {
                      name = "B2_URL";
                      value = cfg.b2.url;
                    }
                    {
                      name = "B2_BUCKET_NAME";
                      value = cfg.b2.bucketName;
                    }
                    {
                      name = "B2_BUCKET_PATH_PREFIX";
                      value = cfg.b2.bucketPathPrefix;
                    }
                    {
                      name = "B2_BUCKET_ID";
                      valueFrom.secretKeyRef = {
                        name = "mie-secrets";
                        key = "b2BucketId";
                      };
                    }
                    {
                      name = "B2_KEY_ID";
                      valueFrom.secretKeyRef = {
                        name = "mie-secrets";
                        key = "b2KeyId";
                      };
                    }
                    {
                      name = "B2_APPLICATION_KEY";
                      valueFrom.secretKeyRef = {
                        name = "mie-secrets";
                        key = "b2ApplicationKey";
                      };
                    }
                    {
                      name = "DISCORD_TOKEN";
                      valueFrom.secretKeyRef = {
                        name = "mie-secrets";
                        key = "discordToken";
                      };
                    }
                  ];
                  resources = {
                    requests = {
                      memory = "100Mi";
                      cpu = "0.1";
                    };
                    limits = {
                      memory = "2Gi";
                      cpu = "1";
                    };
                  };
                }
              ];
            };
          };
        };
      };
    };
    secrets = [
      {
        metadata = {
          name = "mie-secrets";
          namespace = "mie";
        };
        stringData = {
          b2BucketId = cfg.b2.bucketId;
          b2KeyId = cfg.b2.keyId;
          b2ApplicationKey = cfg.b2.applicationKey;
          discordToken = cfg.discordToken;
        };
      }
    ];
  };
}
