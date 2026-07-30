{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  cfg = config.homelab.minecraft;
  namespace = "minecraft";
  minecraftPort = 25565;

  serverNames = lib.attrNames cfg.servers;
  autoRestartServerNames = lib.filter (name: cfg.servers.${name}.autoRestart.enable) serverNames;
  proxiedServerNames = lib.filter (name: cfg.servers.${name}.directPort == null) serverNames;
  directPorts = lib.filter (port: port != null) (map (name: cfg.servers.${name}.directPort) serverNames);
  nameRegex = "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$";
  validServerName = name:
    builtins.match nameRegex name != null && builtins.stringLength name <= 53;

  serverServiceName = name: "minecraft-${name}";
  restartServiceAccountName = "minecraft-restart";
  restartResourceName = name:
    if builtins.stringLength name <= 41
    then "mc-restart-${name}"
    else "mc-restart-${builtins.substring 0 32 name}-${builtins.substring 0 8 (builtins.hashString "sha256" name)}";
  parseTwoDigits = value: builtins.fromJSON (lib.removePrefix "0" (builtins.substring 0 2 value));
  restartSchedule = time: let
    restartMinutes = parseTwoDigits time * 60 + parseTwoDigits (builtins.substring 3 2 time);
    rawWarningMinutes = restartMinutes - 5;
    warningMinutes =
      if rawWarningMinutes < 0
      then rawWarningMinutes + 1440
      else rawWarningMinutes;
    warningHour = builtins.div warningMinutes 60;
    warningMinute = warningMinutes - warningHour * 60;
  in "${toString warningMinute} ${toString warningHour} * * *";
  serverLabels = name: {
    "app.kubernetes.io/name" = "minecraft-server";
    "app.kubernetes.io/instance" = name;
  };
  environmentValueType = types.oneOf [types.str types.int types.bool];
  environmentValueToString = value:
    if builtins.isBool value
    then
      if value
      then "true"
      else "false"
    else toString value;
  mkEnv = environment:
    lib.mapAttrsToList (name: value: {
      inherit name;
      value = environmentValueToString value;
    })
    environment;
  routerResourceName = "minecraft-router";
  routerServiceAccountName = "minecraft-router";
  routerLabels = {
    "app.kubernetes.io/name" = routerResourceName;
  };
  defaultRouterServer =
    if cfg.defaultServer != null
    then cfg.defaultServer
    else if builtins.length proxiedServerNames == 1
    then lib.head proxiedServerNames
    else null;
  routerServiceAnnotations = name:
    {
      "mc-router.itzg.me/externalServerName" = cfg.servers.${name}.domain;
    }
    // lib.optionalAttrs (defaultRouterServer == name) {
      "mc-router.itzg.me/defaultServer" = "true";
    };
  routerEnv = [
    {
      name = "PORT";
      value = toString minecraftPort;
    }
    {
      name = "KUBE_NAMESPACE";
      value = namespace;
    }
  ];

  mkRestartResource = name: let
    server = cfg.servers.${name};
    labels = {
      "app.kubernetes.io/name" = "minecraft-restart";
      "app.kubernetes.io/instance" = name;
    };
    restartScript = ''
      set -eu

      namespace=${lib.escapeShellArg namespace}
      selector=${lib.escapeShellArg "app.kubernetes.io/name=minecraft-server,app.kubernetes.io/instance=${name}"}

      get_pod() {
        kubectl get pods \
          --namespace "$namespace" \
          --selector "$selector" \
          --field-selector status.phase=Running \
          --output 'jsonpath={.items[0].metadata.name}'
      }

      send_command() {
        attempts=0
        until kubectl exec --namespace "$namespace" "$pod" --container minecraft -- rcon-cli "$1"; do
          attempts=$((attempts + 1))
          if [ "$attempts" -ge 12 ]; then
            return 1
          fi
          sleep 5
        done
      }

      pod=$(get_pod)
      if [ -z "$pod" ]; then
        echo "No running Minecraft pod found for $selector" >&2
        exit 1
      fi

      send_command ${lib.escapeShellArg "say ${server.autoRestart.warningMessage}"}
      sleep 300

      pod=$(get_pod)
      if [ -z "$pod" ]; then
        echo "No running Minecraft pod found for $selector after warning delay" >&2
        exit 1
      fi

      send_command ${lib.escapeShellArg "say ${server.autoRestart.restartMessage}"}
      kubectl delete pod --namespace "$namespace" "$pod" --wait=true --timeout=150s
    '';
  in {
    apiVersion = "batch/v1";
    kind = "CronJob";
    metadata = {
      name = restartResourceName name;
      inherit namespace labels;
    };
    spec = {
      schedule = restartSchedule server.autoRestart.time;
      timeZone = server.autoRestart.timeZone;
      concurrencyPolicy = "Forbid";
      startingDeadlineSeconds = 60;
      successfulJobsHistoryLimit = 1;
      failedJobsHistoryLimit = 1;
      jobTemplate.spec = {
        backoffLimit = 0;
        activeDeadlineSeconds = 900;
        ttlSecondsAfterFinished = 86400;
        template = {
          metadata.labels = labels;
          spec = {
            serviceAccountName = restartServiceAccountName;
            restartPolicy = "Never";
            containers = [
              {
                name = "restart";
                image = "docker.io/alpine/k8s:1.35.4";
                imagePullPolicy = "IfNotPresent";
                command = ["/bin/sh" "-c"];
                args = [restartScript];
              }
            ];
          };
        };
      };
    };
  };

  mkServerResources = name: let
    server = cfg.servers.${name};
    labels = serverLabels name;
    serviceName = serverServiceName name;
    dataVolumeName = "${serviceName}-data";
    servicePort =
      if server.directPort != null
      then server.directPort
      else minecraftPort;
    environment =
      server.environment
      // {
        EULA = true;
      }
      // lib.optionalAttrs (server.jarUrl != null) {
        TYPE = "CUSTOM";
        CUSTOM_SERVER = server.jarUrl;
      }
      // lib.optionalAttrs server.autoRestart.enable {
        ENABLE_RCON = true;
        RCON_PASSWORD = server.environment.RCON_PASSWORD or "minecraft";
      };
  in [
    {
      apiVersion = "v1";
      kind = "PersistentVolume";
      metadata = {
        name = dataVolumeName;
        labels = labels;
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
          name = dataVolumeName;
          namespace = namespace;
        };
      };
    }
    {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = dataVolumeName;
        namespace = namespace;
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        storageClassName = "local-path";
        volumeName = dataVolumeName;
        resources.requests.storage = server.storageSize;
      };
    }
    {
      apiVersion = "apps/v1";
      kind = "StatefulSet";
      metadata = {
        name = serviceName;
        namespace = namespace;
        labels = labels;
      };
      spec = {
        serviceName = serviceName;
        replicas = 1;
        selector.matchLabels = labels;
        template = {
          metadata.labels = labels;
          spec = {
            terminationGracePeriodSeconds = 120;
            restartPolicy = "Always";
            containers = [
              {
                name = "minecraft";
                image = "itzg/minecraft-server:java${toString server.javaVersion}";
                imagePullPolicy = "IfNotPresent";
                ports = [
                  {
                    name = "minecraft";
                    containerPort = minecraftPort;
                    protocol = "TCP";
                  }
                ];
                env = mkEnv environment;
                volumeMounts = [
                  {
                    name = "data";
                    mountPath = "/data";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = dataVolumeName;
              }
            ];
          };
        };
      };
    }
    {
      apiVersion = "v1";
      kind = "Service";
      metadata =
        {
          name = serviceName;
          namespace = namespace;
        }
        // lib.optionalAttrs (server.directPort == null) {
          annotations = routerServiceAnnotations name;
        };
      spec = {
        type =
          if server.directPort != null
          then "LoadBalancer"
          else "ClusterIP";
        selector = labels;
        ports = [
          {
            name = "minecraft";
            protocol = "TCP";
            port = servicePort;
            targetPort = minecraftPort;
          }
        ];
      };
    }
  ];
in {
  options.homelab.minecraft = {
    enable = lib.mkEnableOption "minecraft";
    defaultServer = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Server used when mc-router cannot match the requested Minecraft domain.";
    };
    servers = lib.mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          domain = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Domain routed by mc-router to this Minecraft server; required unless directPort is set.";
          };
          directPort = lib.mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Optional external TCP port that exposes this server directly instead of through mc-router.";
          };
          jarUrl = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional custom server jar URL, mapped to TYPE=CUSTOM and CUSTOM_SERVER.";
          };
          dataPath = lib.mkOption {
            type = types.str;
            default = "/opt/kubernetes/minecraft/${name}";
            description = "Host path backing this server's persistent data volume.";
          };
          storageSize = lib.mkOption {
            type = types.str;
            default = "10Gi";
            description = "Requested size for this server's PersistentVolume and PersistentVolumeClaim.";
          };
          javaVersion = lib.mkOption {
            type = types.enum [8 11 16 17 21 25];
            default = 21;
            description = "Java version tag for the itzg/minecraft-server image.";
          };
          autoRestart = {
            enable = lib.mkEnableOption "daily graceful restarts for this Minecraft server";
            time = lib.mkOption {
              type = types.strMatching "^([01][0-9]|2[0-3]):[0-5][0-9]$";
              default = "04:00";
              description = "Daily restart time for this server in 24-hour HH:MM format.";
            };
            timeZone = lib.mkOption {
              type = types.str;
              default = "UTC";
              description = "Timezone used to interpret this server's daily restart time.";
            };
            warningMessage = lib.mkOption {
              type = types.str;
              default = "Server restarting in 5 minutes.";
              description = "Chat message sent five minutes before this server restarts.";
            };
            restartMessage = lib.mkOption {
              type = types.str;
              default = "Server restarting now.";
              description = "Chat message sent immediately before this server restarts.";
            };
          };
          environment = lib.mkOption {
            type = types.attrsOf environmentValueType;
            default = {};
            example = {
              MEMORY = "4G";
              VERSION = "1.21.6";
              TYPE = "PAPER";
              ENABLE_RCON = false;
            };
            description = "Environment variables passed to itzg/minecraft-server for upstream image configuration.";
          };
        };
      }));
      default = {};
      description = "Minecraft servers keyed by Kubernetes-safe server name.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all validServerName serverNames;
        message = "homelab.minecraft.servers keys must be lowercase Kubernetes names and fit the minecraft- prefix.";
      }
      {
        assertion = cfg.defaultServer == null || builtins.elem cfg.defaultServer proxiedServerNames;
        message = "homelab.minecraft.defaultServer must name a configured server without directPort.";
      }
      {
        assertion = lib.all (name: cfg.servers.${name}.domain != null) proxiedServerNames;
        message = "homelab.minecraft servers without directPort must configure domain.";
      }
      {
        assertion = builtins.length directPorts == builtins.length (lib.unique directPorts);
        message = "homelab.minecraft directPort values must be unique.";
      }
      {
        assertion = proxiedServerNames == [] || lib.all (port: port != minecraftPort) directPorts;
        message = "homelab.minecraft directPort cannot be 25565 while mc-router is enabled.";
      }
    ];

    networking.firewall.allowedTCPPorts = directPorts ++ lib.optionals (proxiedServerNames != []) [minecraftPort];

    services.k3s.manifests.minecraft.content =
      [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata.name = namespace;
        }
      ]
      ++ lib.optionals (autoRestartServerNames != []) [
        {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata = {
            name = restartServiceAccountName;
            inherit namespace;
          };
        }
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "Role";
          metadata = {
            name = restartServiceAccountName;
            inherit namespace;
          };
          rules = [
            {
              apiGroups = [""];
              resources = ["pods"];
              verbs = ["get" "list" "delete"];
            }
            {
              apiGroups = [""];
              resources = ["pods/exec"];
              verbs = ["create"];
            }
          ];
        }
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "RoleBinding";
          metadata = {
            name = restartServiceAccountName;
            inherit namespace;
          };
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "Role";
            name = restartServiceAccountName;
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = restartServiceAccountName;
              inherit namespace;
            }
          ];
        }
      ]
      ++ lib.optionals (proxiedServerNames != []) [
        {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata = {
            name = routerServiceAccountName;
            inherit namespace;
          };
        }
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "Role";
          metadata = {
            name = routerServiceAccountName;
            inherit namespace;
          };
          rules = [
            {
              apiGroups = [""];
              resources = ["services"];
              verbs = ["list" "watch"];
            }
          ];
        }
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "RoleBinding";
          metadata = {
            name = routerServiceAccountName;
            inherit namespace;
          };
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "Role";
            name = routerServiceAccountName;
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = routerServiceAccountName;
              inherit namespace;
            }
          ];
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = routerResourceName;
            namespace = namespace;
            labels = routerLabels;
          };
          spec = {
            replicas = 1;
            selector.matchLabels = routerLabels;
            template = {
              metadata.labels = routerLabels;
              spec = {
                serviceAccountName = routerServiceAccountName;
                containers = [
                  {
                    name = "mc-router";
                    image = "itzg/mc-router";
                    imagePullPolicy = "IfNotPresent";
                    args = ["--in-kube-cluster"];
                    ports = [
                      {
                        name = "minecraft";
                        containerPort = minecraftPort;
                        protocol = "TCP";
                      }
                    ];
                    env = routerEnv;
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
            name = routerResourceName;
            namespace = namespace;
          };
          spec = {
            type = "LoadBalancer";
            selector = routerLabels;
            ports = [
              {
                name = "minecraft";
                protocol = "TCP";
                port = minecraftPort;
                targetPort = minecraftPort;
              }
            ];
          };
        }
      ]
      ++ lib.concatMap mkServerResources serverNames
      ++ map mkRestartResource autoRestartServerNames;
  };
}
