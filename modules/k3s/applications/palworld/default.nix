{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  cfg = config.homelab.palworld;
  namespace = "palworld";
  environmentValueType = types.oneOf [types.str types.int types.bool];
  nameRegex = "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$";
  serverNames = lib.attrNames cfg.servers;
  dataPaths = map (name: cfg.servers.${name}.dataPath) serverNames;
  validServerName = name:
    builtins.match nameRegex name != null && builtins.stringLength name <= 53;

  environmentValueToString = value:
    if builtins.isBool value
    then
      if value
      then "true"
      else "false"
    else toString value;

  mkServerResources = name: let
    server = cfg.servers.${name};
    resourceName = "palworld-${name}";
    labels = {
      "app.kubernetes.io/name" = "palworld";
      "app.kubernetes.io/instance" = name;
    };
    environment =
      {
        TZ = "UTC";
        PLAYERS = 16;
        PUID = 1000;
        PGID = 1000;
        COMMUNITY = false;
        REST_API_ENABLED = true;
        CROSSPLAY_PLATFORMS = "(Steam,Xbox,PS5,Mac)";
      }
      // server.environment
      // {
        PORT = server.ports.server;
        QUERY_PORT = server.ports.query;
        REST_API_PORT = server.ports.restApi;
        RCON_PORT = server.ports.rcon;
      };
    configMapData = lib.mapAttrs (_: environmentValueToString) environment;
    containerPorts = [
      {
        name = "server";
        containerPort = server.ports.server;
        protocol = "UDP";
      }
      {
        name = "query";
        containerPort = server.ports.query;
        protocol = "UDP";
      }
      {
        name = "rest-api";
        containerPort = server.ports.restApi;
        protocol = "TCP";
      }
      {
        name = "rcon";
        containerPort = server.ports.rcon;
        protocol = "TCP";
      }
    ];
    servicePorts =
      [
        {
          name = "server";
          port = server.ports.server;
          targetPort = "server";
          protocol = "UDP";
        }
      ]
      ++ lib.optionals server.service.exposeQuery [
        {
          name = "query";
          port = server.ports.query;
          targetPort = "query";
          protocol = "UDP";
        }
      ]
      ++ lib.optionals server.service.exposeRestApi [
        {
          name = "rest-api";
          port = server.ports.restApi;
          targetPort = "rest-api";
          protocol = "TCP";
        }
      ]
      ++ lib.optionals server.service.exposeRcon [
        {
          name = "rcon";
          port = server.ports.rcon;
          targetPort = "rcon";
          protocol = "TCP";
        }
      ];
  in [
    {
      apiVersion = "v1";
      kind = "ConfigMap";
      metadata = {
        name = resourceName;
        inherit namespace labels;
      };
      data = configMapData;
    }
    {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata = {
        name = resourceName;
        inherit labels;
      };
      spec = {
        capacity.storage = server.storageSize;
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        persistentVolumeReclaimPolicy = "Retain";
        hostPath = {
          path = server.dataPath;
          type = "DirectoryOrCreate";
        };
        claimRef = {
          name = resourceName;
          inherit namespace;
        };
      };
    }
    {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = resourceName;
        inherit namespace labels;
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        volumeName = resourceName;
        resources.requests.storage = server.storageSize;
      };
    }
    {
      apiVersion = "apps/v1";
      kind = "StatefulSet";
      metadata = {
        name = resourceName;
        inherit namespace labels;
      };
      spec = {
        serviceName = resourceName;
        replicas = 1;
        selector.matchLabels = labels;
        template = {
          metadata = {
            inherit labels;
            annotations."checksum/environment" = builtins.hashString "sha256" (builtins.toJSON configMapData);
          };
          spec = {
            terminationGracePeriodSeconds = 30;
            containers = [
              {
                name = "palworld";
                image = server.image;
                imagePullPolicy = "Always";
                ports = containerPorts;
                envFrom = [
                  {configMapRef.name = resourceName;}
                  {secretRef.name = resourceName;}
                ];
                resources = server.resources;
                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/palworld";
                  }
                ];
                startupProbe = {
                  exec.command = ["sh" "-c" "pgrep PalServer-Linux >/dev/null"];
                  failureThreshold = 120;
                  periodSeconds = 5;
                };
                readinessProbe = {
                  exec.command = ["sh" "-c" "pgrep PalServer-Linux >/dev/null"];
                  periodSeconds = 10;
                };
                livenessProbe = {
                  exec.command = ["sh" "-c" "pgrep PalServer-Linux >/dev/null"];
                  periodSeconds = 20;
                };
              }
            ];
            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = resourceName;
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
        name = resourceName;
        inherit namespace;
        inherit (server.service) annotations;
      };
      spec =
        {
          inherit (server.service) type;
          selector = labels;
          ports = servicePorts;
        }
        // lib.optionalAttrs (server.service.loadBalancerIP != null) {
          inherit (server.service) loadBalancerIP;
        };
    }
  ];
in {
  options.homelab.palworld = {
    enable = lib.mkEnableOption "Palworld dedicated servers";

    servers = lib.mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          image = lib.mkOption {
            type = types.str;
            default = "thijsvanloef/palworld-server-docker:latest";
            description = "Palworld server container image.";
          };

          dataPath = lib.mkOption {
            type = types.strMatching "^/.*";
            default = "/opt/kubernetes/palworld/${name}";
            description = "Host path for this server's data and Borg backups.";
          };

          storageSize = lib.mkOption {
            type = types.str;
            default = "20Gi";
            description = "Requested size for this server's PersistentVolume and PersistentVolumeClaim.";
          };

          ports = {
            server = lib.mkOption {
              type = types.port;
              default = 8211;
              description = "UDP game server port, also passed as PORT.";
            };
            query = lib.mkOption {
              type = types.port;
              default = 27015;
              description = "UDP community server query port, also passed as QUERY_PORT.";
            };
            restApi = lib.mkOption {
              type = types.port;
              default = 8212;
              description = "TCP REST API port, also passed as REST_API_PORT.";
            };
            rcon = lib.mkOption {
              type = types.port;
              default = 25575;
              description = "TCP RCON port, also passed as RCON_PORT.";
            };
          };

          service = {
            type = lib.mkOption {
              type = types.enum ["ClusterIP" "NodePort" "LoadBalancer"];
              default = "LoadBalancer";
              description = "Kubernetes service type used to expose this server.";
            };
            annotations = lib.mkOption {
              type = types.attrsOf types.str;
              default = {};
              description = "Annotations applied to this server's service.";
            };
            loadBalancerIP = lib.mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional fixed IP for this server's LoadBalancer service.";
            };
            exposeQuery = lib.mkOption {
              type = types.bool;
              default = true;
              description = "Expose this server's community query port.";
            };
            exposeRestApi = lib.mkOption {
              type = types.bool;
              default = false;
              description = "Expose this server's REST API; leave disabled for untrusted networks.";
            };
            exposeRcon = lib.mkOption {
              type = types.bool;
              default = false;
              description = "Expose this server's RCON port; leave disabled for untrusted networks.";
            };
          };

          resources = lib.mkOption {
            type = types.attrsOf types.anything;
            default = {
              requests = {
                cpu = "2";
                memory = "6Gi";
              };
              limits = {
                cpu = "8";
                memory = "16Gi";
              };
            };
            description = "Kubernetes resource requests and limits for this server.";
          };

          environment = lib.mkOption {
            type = types.attrsOf environmentValueType;
            default = {};
            example = {
              SERVER_NAME = "My Palworld Server";
              PLAYERS = 16;
              BACKUP_ENABLED = true;
              AUTO_UPDATE_ENABLED = false;
              PAL_EGG_DEFAULT_HATCHING_TIME = "1.000000";
            };
            description = "Environment variables passed to palworld-server-docker. Configure its four network ports through ports.";
          };

          secretEnvironment = lib.mkOption {
            type = types.attrsOf types.str;
            default = {};
            example = {
              ADMIN_PASSWORD = "sops placeholder or plain value";
              SERVER_PASSWORD = "sops placeholder or plain value";
            };
            description = "Sensitive environment variables rendered into a Kubernetes Secret; values may use sops placeholders.";
          };
        };
      }));
      default = {};
      description = "Palworld servers keyed by Kubernetes-safe server name.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.system.borgbackup.daily.enable;
        message = "homelab.palworld requires system.borgbackup.daily.enable so its data is backed up.";
      }
      {
        assertion = cfg.servers != {};
        message = "homelab.palworld.servers must contain at least one server.";
      }
      {
        assertion = lib.all validServerName serverNames;
        message = "homelab.palworld.servers keys must be lowercase Kubernetes names and fit the palworld- prefix.";
      }
      {
        assertion = builtins.length dataPaths == builtins.length (lib.unique dataPaths);
        message = "homelab.palworld servers must use distinct dataPath values.";
      }
    ];

    system.borgbackup.daily.extraPaths = dataPaths;

    networking.firewall.allowedUDPPorts = lib.concatMap (name: let
      server = cfg.servers.${name};
    in
      [server.ports.server]
      ++ lib.optionals server.service.exposeQuery [server.ports.query])
    serverNames;
    networking.firewall.allowedTCPPorts = lib.concatMap (name: let
      server = cfg.servers.${name};
    in
      lib.optionals server.service.exposeRestApi [server.ports.restApi]
      ++ lib.optionals server.service.exposeRcon [server.ports.rcon])
    serverNames;

    services.k3s.manifests.palworld.content =
      [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata.name = namespace;
        }
      ]
      ++ lib.concatMap mkServerResources serverNames;

    services.k3s.secrets =
      map (name: let
        server = cfg.servers.${name};
      in {
        metadata = {
          name = "palworld-${name}";
          inherit namespace;
        };
        stringData = server.secretEnvironment;
      })
      serverNames;
  };
}
