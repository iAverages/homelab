{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.atuin;
in {
  options.homelab.atuin = {
    enable = lib.mkEnableOption "atuin";
    domain = lib.mkOption {
      type = lib.types.str;
      default = "atuin." + config.homelab.domain;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    manifests = {
      atuin-namespace.content = {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "atuin";
        };
      };
      atuin-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "atuin";
          namespace = "atuin";
          labels = {app = "atuin";};
        };
        spec = {
          selector = {matchLabels = {app = "atuin";};};
          replicas = 1;
          template = {
            metadata = {labels = {app = "atuin";};};
            spec = {
              containers = [
                {
                  args = ["server" "start"];
                  env = [
                    {
                      name = "ATUIN_DB_URI";
                      valueFrom = {
                        secretKeyRef = {
                          name = "atuin-db-app";
                          key = "fqdn-uri";
                          optional = false;
                        };
                      };
                    }
                    {
                      name = "ATUIN_HOST";
                      value = "0.0.0.0";
                    }
                    {
                      name = "ATUIN_PORT";
                      value = "8888";
                    }
                    {
                      name = "ATUIN_OPEN_REGISTRATION";
                      value = "true";
                    }
                  ];
                  image = "ghcr.io/atuinsh/atuin:v18.10.0";
                  name = "atuin";
                  ports = [
                    {
                      name = "http";
                      containerPort = 8888;
                    }
                  ];
                  resources = {
                    limits = {
                      cpu = "250m";
                      memory = "1Gi";
                    };
                    requests = {
                      cpu = "250m";
                      memory = "1Gi";
                    };
                  };
                  # volumeMounts = [
                  #   {
                  #     mountPath = "/config";
                  #     name = "atuin-pvc";
                  #   }
                  # ];
                }
              ];
              # volumes = [
              #   {
              #     name = "atuin-pvc";
              #     persistentVolumeClaim = {claimName = "atuin-pvc";};
              #   }
              # ];
            };
          };
        };
      };

      atuin-pv.content = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "atuin-pv";
          namespace = "atuin";
        };
        spec = {
          capacity = {storage = "10Mi";};
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          persistentVolumeReclaimPolicy = "Retain";
          hostPath = {path = "/opt/kubernetes/atuin";};
        };
      };
      atuin-pvc.content = {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "atuin-pvc";
          namespace = "atuin";
        };
        spec = {
          resources = {requests = {storage = "10Mi";};};
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          volumeName = "atuin-pv";
        };
      };

      atuin-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "atuin-service";
          namespace = "atuin";
        };
        spec = {
          selector = {app = "atuin";};
          ports = [
            {
              name = "http";
              protocol = "TCP";
              port = 8888;
              targetPort = 8888;
            }
          ];
        };
      };
      atuin-ingress.content = {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "atuin-ingress";
          namespace = "atuin";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              host = "atuin.dan.local";
              http = {
                paths = [
                  {
                    path = "/";
                    pathType = "Prefix";
                    backend = {
                      service = {
                        name = "atuin-service";
                        port = {number = 8888;};
                      };
                    };
                  }
                ];
              };
            }
          ];
        };
      };

      atuin-database.content = {
        apiVersion = "postgresql.cnpg.io/v1";
        kind = "Cluster";
        metadata = {
          name = "atuin-db";
          namespace = "atuin";
        };
        spec = {
          instances = 1;
          storage = {size = "1Gi";};
        };
      };
      atuin-database-monitor.content = {
        apiVersion = "monitoring.coreos.com/v1";
        kind = "PodMonitor";
        metadata = {
          name = "atuin-database-monitor";
          namespace = "atuin";
        };
        spec = {
          selector = {matchLabels = {"cnpg.io/cluster" = "atuin-db";};};
          podMetricsEndpoints = [{port = "metrics";}];
        };
      };
    };
  };
}
