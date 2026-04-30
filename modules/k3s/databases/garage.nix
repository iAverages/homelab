{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.garage;
  inherit (lib) types;
in {
  options.homelab.garage = {
    enable = lib.mkEnableOption "garage";

    adminToken = lib.mkOption {
      type = types.str;
    };

    replicas = lib.mkOption {
      type = types.int;
      default = 1;
      description = "Number of garage replicas";
    };

    replicationFactor = lib.mkOption {
      type = types.int;
      default = 1;
    };

    consistencyMode = lib.mkOption {
      type = types.enum [
        "consistent"
        "degraded"
        "dangerous"
      ];
      default = "consistent";
    };

    s3Region = lib.mkOption {
      type = types.str;
      default = "garage";
    };

    host = lib.mkOption {
      type = types.str;
      default = "s3." + config.homelab.domain;
    };

    storage = {
      dataSize = lib.mkOption {
        type = types.str;
      };

      metaSize = lib.mkOption {
        type = types.str;
        default = "1Gi";
        description = "Size of metadata volume";
      };

      storageClass = lib.mkOption {
        type = types.str;
        default = "local-path";
        description = "Storage class for persistent volumes";
      };
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    autoDeployCharts.garage = {
      name = "garage-operator";
      repo = "oci://ghcr.io/rajsinghtech/charts/garage-operator";
      version = "0.3.16";
      hash = "sha256-q/bkPsLGe557dvMLcN0gFD8gW4SeK9SMkz8kKzMiAjg=";
      targetNamespace = "garage";
      createNamespace = true;
      values = {};
    };

    manifests.garage-cluster.content = [
      {
        apiVersion = "garage.rajsingh.info/v1alpha1";
        kind = "GarageCluster";
        metadata = {
          name = "garage";
          namespace = "garage";
          labels = {
            "app.kubernetes.io/name" = "garage";
          };
        };
        spec = {
          replicas = 1;
          zone = cfg.s3Region;
          replication = {
            factor = 1;
          };
          storage = {
            data = {
              size = cfg.storage.dataSize;
            };
          };
          network = {
            rpcBindPort = 3901;
            service = {
              type = "ClusterIP";
            };
          };
          admin = {
            enabled = true;
            bindPort = 3903;
            adminTokenSecretRef = {
              name = "garage-secrets";
              key = "admin-token";
            };
          };
        };
      }
    ];

    manifests.garage-webui.content = [
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "garage-webui";
          namespace = "garage";
          labels."app.kubernetes.io/name" = "garage-webui";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "garage-webui";
          template = {
            metadata.labels."app.kubernetes.io/name" = "garage-webui";
            spec.containers = [
              {
                name = "garage-webui";
                image = "khairul169/garage-webui:latest";
                ports = [{containerPort = 3909;}];
                env = [
                  {
                    name = "API_BASE_URL";
                    value = "http://garage:3903";
                  }
                  {
                    name = "S3_ENDPOINT_URL";
                    value = "http://garage:3900";
                  }
                  {
                    name = "S3_REGION";
                    value = cfg.s3Region;
                  }
                  {
                    name = "API_ADMIN_KEY";
                    valueFrom.secretKeyRef = {
                      name = "garage-secrets";
                      key = "admin-token";
                    };
                  }
                ];
              }
            ];
          };
        };
      }
      {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "garage-webui";
          namespace = "garage";
          labels."app.kubernetes.io/name" = "garage-webui";
        };
        spec = {
          selector."app.kubernetes.io/name" = "garage-webui";
          ports = [
            {
              port = 3909;
              targetPort = 3909;
            }
          ];
        };
      }
    ];

    secrets = [
      {
        metadata = {
          name = "garage-secrets";
          namespace = "garage";
        };
        stringData = {
          admin-token = cfg.adminToken;
        };
      }
    ];
  };
}
