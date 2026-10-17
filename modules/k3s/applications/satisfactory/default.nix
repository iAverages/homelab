{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  cfg = config.homelab.satisfactory;
  namespace = "satisfactory";
  environmentValueType = types.oneOf [types.str types.int types.bool];
  nameRegex = "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$";
  serverNames = lib.attrNames cfg.servers;
  dataPaths = map (name: cfg.servers.${name}.dataPath) serverNames;
  validServerName = name:
    builtins.match nameRegex name != null && builtins.stringLength name <= 50;

  environmentValueToString = value:
    if builtins.isBool value
    then
      if value
      then "true"
      else "false"
    else toString value;

  mkServerResources = name: let
    server = cfg.servers.${name};
    resourceName = "satisfactory-${name}";
    labels = {
      "app.kubernetes.io/name" = "satisfactory";
      "app.kubernetes.io/instance" = name;
    };
    environment =
      {
        TZ = "UTC";
        PUID = 1000;
        PGID = 1000;
        MAXPLAYERS = 4;
      }
      // server.environment
      // {
        SERVERGAMEPORT = server.ports.game;
        SERVERMESSAGINGPORT = server.ports.messaging;
      };
    configMapData = lib.mapAttrs (_: environmentValueToString) environment;
    # The image's healthcheck queries the HTTPS API on the game port.
    healthCheck = ["bash" "/home/steam/healthcheck.sh"];
    containerPorts = [
      {
        name = "game-udp";
        containerPort = server.ports.game;
        protocol = "UDP";
      }
      {
        name = "game-tcp";
        containerPort = server.ports.game;
        protocol = "TCP";
      }
      {
        name = "messaging";
        containerPort = server.ports.messaging;
        protocol = "TCP";
      }
    ];
    servicePorts = [
      {
        name = "game-udp";
        port = server.ports.game;
        targetPort = "game-udp";
        protocol = "UDP";
      }
      {
        name = "game-tcp";
        port = server.ports.game;
        targetPort = "game-tcp";
        protocol = "TCP";
      }
      {
        name = "messaging";
        port = server.ports.messaging;
        targetPort = "messaging";
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
            terminationGracePeriodSeconds = 60;
            containers = [
              {
                name = "satisfactory";
                image = server.image;
                imagePullPolicy = "Always";
                ports = containerPorts;
                envFrom = [
                  {configMapRef.name = resourceName;}
                ];
                resources = server.resources;
                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/config";
                  }
                ];
                # First boot downloads the dedicated server, so allow up to an hour.
                startupProbe = {
                  exec.command = healthCheck;
                  failureThreshold = 360;
                  periodSeconds = 10;
                  timeoutSeconds = 30;
                };
                readinessProbe = {
                  exec.command = healthCheck;
                  periodSeconds = 30;
                  timeoutSeconds = 30;
                };
                livenessProbe = {
                  exec.command = healthCheck;
                  failureThreshold = 5;
                  periodSeconds = 60;
                  timeoutSeconds = 30;
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
  options.homelab.satisfactory = {
    enable = lib.mkEnableOption "Satisfactory dedicated servers";

    servers = lib.mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          image = lib.mkOption {
            type = types.str;
            default = "wolveix/satisfactory-server:latest";
            description = "Satisfactory server container image.";
          };

          dataPath = lib.mkOption {
            type = types.strMatching "^/.*";
            default = "/opt/kubernetes/satisfactory/${name}";
            description = "Host path for this server's data and Borg backups.";
          };

          storageSize = lib.mkOption {
            type = types.str;
            default = "30Gi";
            description = "Requested size for this server's PersistentVolume and PersistentVolumeClaim.";
          };

          ports = {
            game = lib.mkOption {
              type = types.port;
              default = 7777;
              description = "UDP/TCP game and HTTPS API port, also passed as SERVERGAMEPORT.";
            };
            messaging = lib.mkOption {
              type = types.port;
              default = 8888;
              description = "TCP reliable messaging port, also passed as SERVERMESSAGINGPORT.";
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
          };

          resources = lib.mkOption {
            type = types.attrsOf types.anything;
            default = {
              requests = {
                cpu = "2";
                memory = "8Gi";
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
              MAXPLAYERS = 8;
              AUTOSAVENUM = 10;
              SKIPUPDATE = false;
            };
            description = "Environment variables passed to satisfactory-server. Configure its network ports through ports.";
          };
        };
      }));
      default = {};
      description = "Satisfactory servers keyed by Kubernetes-safe server name.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.system.borgbackup.daily.enable;
        message = "homelab.satisfactory requires system.borgbackup.daily.enable so its data is backed up.";
      }
      {
        assertion = cfg.servers != {};
        message = "homelab.satisfactory.servers must contain at least one server.";
      }
      {
        assertion = lib.all validServerName serverNames;
        message = "homelab.satisfactory.servers keys must be lowercase Kubernetes names and fit the satisfactory- prefix.";
      }
      {
        assertion = builtins.length dataPaths == builtins.length (lib.unique dataPaths);
        message = "homelab.satisfactory servers must use distinct dataPath values.";
      }
    ];

    system.borgbackup.daily.extraPaths = dataPaths;

    networking.firewall.allowedUDPPorts = map (name: cfg.servers.${name}.ports.game) serverNames;
    networking.firewall.allowedTCPPorts = lib.concatMap (name: let
      server = cfg.servers.${name};
    in [server.ports.game server.ports.messaging])
    serverNames;

    services.k3s.manifests.satisfactory.content =
      [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata.name = namespace;
        }
      ]
      ++ lib.concatMap mkServerResources serverNames;
  };
}
