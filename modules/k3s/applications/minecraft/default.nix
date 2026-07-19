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
  haproxyLabels = {
    "app.kubernetes.io/name" = "minecraft-haproxy";
  };
  defaultBackend =
    if cfg.defaultServer != null
    then serverServiceName cfg.defaultServer
    else if builtins.length proxiedServerNames == 1
    then serverServiceName (lib.head proxiedServerNames)
    else "minecraft-unmatched";
  proxyProtocolOption = proxyProtocol:
    if proxyProtocol == "v1"
    then " send-proxy"
    else if proxyProtocol == "v2"
    then " send-proxy-v2"
    else "";
  domainMatcher = server: "{ var(txn.mc_host) -i -m str ${server.domain} }";

  minecraftLua = ''
    local string_byte = string.byte
    local string_find = string.find
    local string_len = string.len
    local string_sub = string.sub

    local function readable(payload)
      return string_len(payload.data) - payload.index + 1
    end

    local function read_varint(payload, max_bytes, nil_on_eof)
      local value = 0
      local bytes = 0

      while true do
        local byte = string_byte(payload.data, payload.index + bytes)
        if byte == nil then
          if nil_on_eof then
            return nil, "need"
          end
          return nil, "error"
        end

        value = value | ((byte & 0x7f) << (bytes * 7))
        bytes = bytes + 1

        if byte < 0x80 then
          payload.index = payload.index + bytes
          return value
        end

        if bytes >= max_bytes then
          payload.index = payload.index + bytes
          return nil, "error"
        end
      end
    end

    local function read_string(payload, max_prefix_bytes, max_len)
      local length, err = read_varint(payload, max_prefix_bytes, false)
      if err ~= nil or length > max_len or length > readable(payload) then
        return nil, "error"
      end

      local value = string_sub(payload.data, payload.index, payload.index + length - 1)
      payload.index = payload.index + length
      return value
    end

    local function read_handshake(data)
      local payload = { data = data, index = 1 }

      local packet_len, err = read_varint(payload, 3, true)
      if err == "need" then
        return nil
      end
      if err ~= nil or packet_len > 267 then
        return false
      end
      if packet_len > readable(payload) then
        return nil
      end

      local packet_id
      packet_id, err = read_varint(payload, 1, false)
      if err ~= nil or packet_id ~= 0 then
        return false
      end

      local protocol_version
      protocol_version, err = read_varint(payload, 5, false)
      if err ~= nil or protocol_version <= 0 then
        return false
      end

      local host
      host, err = read_string(payload, 2, 255)
      if err ~= nil then
        return false
      end

      if readable(payload) < 2 then
        return false
      end
      payload.index = payload.index + 2

      local state
      state, err = read_varint(payload, 1, false)
      if err ~= nil or (state ~= 1 and state ~= 2 and state ~= 3) then
        return false
      end

      local nul = string_find(host, "\0", 1, true)
      if nul ~= nil then
        host = string_sub(host, 1, nul - 1)
      end

      return true, protocol_version, host, state
    end

    local function mc_handshake(txn)
      local ok, proto, host, state = read_handshake(txn.req:dup())
      if ok == nil then
        return
      end

      if ok == false then
        txn:set_var("txn.mc_proto", 0)
        txn:set_var("txn.mc_host", "")
        txn:set_var("txn.mc_state", 0)
        return
      end

      txn:set_var("txn.mc_proto", proto)
      txn:set_var("txn.mc_host", host)
      txn:set_var("txn.mc_state", state)
    end

    core.register_action("mc_handshake", { "tcp-req" }, mc_handshake, 0)
  '';

  haproxyConfig = lib.concatStringsSep "\n" (
    [
      "global"
      "  log stdout format raw local0"
      "  maxconn 2048"
      "  lua-load /usr/local/etc/haproxy/minecraft.lua"
      ""
      "defaults"
      "  log global"
      "  mode tcp"
      "  option tcplog"
      "  timeout connect 10s"
      "  timeout client 1h"
      "  timeout server 1h"
      ""
      "frontend minecraft"
      "  bind *:${toString minecraftPort}"
      "  tcp-request inspect-delay 5s"
      "  tcp-request content lua.mc_handshake"
      "  tcp-request content reject if { var(txn.mc_proto) -m int 0 }"
      "  tcp-request content accept if { var(txn.mc_proto) -m found }"
      "  tcp-request content reject if WAIT_END"
    ]
    ++ lib.concatMap (name: let
      server = cfg.servers.${name};
    in [
      "  use_backend ${serverServiceName name} if ${domainMatcher server}"
    ])
    proxiedServerNames
    ++ [
      "  default_backend ${defaultBackend}"
      ""
    ]
    ++ lib.concatMap (name: let
      server = cfg.servers.${name};
      serviceName = serverServiceName name;
    in [
      "backend ${serviceName}"
      "  mode tcp"
      "  server minecraft ${serviceName}.${namespace}.svc.cluster.local:${toString minecraftPort}${proxyProtocolOption server.proxyProtocol}"
      ""
    ])
    proxiedServerNames
    ++ [
      "backend minecraft-unmatched"
      "  mode tcp"
      ""
    ]
  );

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
      restart_count=$(kubectl get pod --namespace "$namespace" "$pod" --output 'jsonpath={.status.containerStatuses[?(@.name=="minecraft")].restartCount}')
      if [ -z "$restart_count" ]; then
        echo "Could not read Minecraft container restart count for $pod" >&2
        exit 1
      fi

      kubectl exec --namespace "$namespace" "$pod" --container minecraft -- rcon-cli stop || true

      attempts=0
      while [ "$attempts" -lt 120 ]; do
        if ! kubectl get pod --namespace "$namespace" "$pod" >/dev/null 2>&1; then
          exit 0
        fi

        current_restart_count=$(kubectl get pod --namespace "$namespace" "$pod" --output 'jsonpath={.status.containerStatuses[?(@.name=="minecraft")].restartCount}')
        if [ -n "$current_restart_count" ] && [ "$current_restart_count" -gt "$restart_count" ]; then
          kubectl delete pod --namespace "$namespace" "$pod" --wait=true --timeout=120s
          exit 0
        fi

        attempts=$((attempts + 1))
        sleep 1
      done

      echo "Minecraft container in $pod did not stop within 120 seconds" >&2
      exit 1
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
      kind = "Deployment";
      metadata = {
        name = serviceName;
        namespace = namespace;
        labels = labels;
      };
      spec = {
        replicas = 1;
        strategy.type = "Recreate";
        selector.matchLabels = labels;
        template = {
          metadata.labels = labels;
          spec = {
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
      metadata = {
        name = serviceName;
        namespace = namespace;
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
      description = "Server used when HAProxy cannot match the requested Minecraft domain.";
    };
    servers = lib.mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          domain = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Domain routed by HAProxy to this Minecraft server; required unless directPort is set.";
          };
          directPort = lib.mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Optional external TCP port that exposes this server directly instead of through HAProxy.";
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
          proxyProtocol = lib.mkOption {
            type = types.nullOr (types.enum ["v1" "v2"]);
            default = null;
            description = "HAProxy PROXY protocol version to send to this Minecraft server.";
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
        message = "homelab.minecraft directPort cannot be 25565 while HAProxy is enabled.";
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
          kind = "ConfigMap";
          metadata = {
            name = "minecraft-haproxy";
            namespace = namespace;
          };
          data."haproxy.cfg" = haproxyConfig;
          data."minecraft.lua" = minecraftLua;
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "minecraft-haproxy";
            namespace = namespace;
            labels = haproxyLabels;
          };
          spec = {
            replicas = 1;
            selector.matchLabels = haproxyLabels;
            template = {
              metadata = {
                labels = haproxyLabels;
                annotations."checksum/config" = builtins.hashString "sha256" (haproxyConfig + minecraftLua);
              };
              spec = {
                containers = [
                  {
                    name = "haproxy";
                    image = "haproxy:3.0-alpine";
                    imagePullPolicy = "IfNotPresent";
                    args = ["-f" "/usr/local/etc/haproxy/haproxy.cfg"];
                    ports = [
                      {
                        name = "minecraft";
                        containerPort = minecraftPort;
                        protocol = "TCP";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "config";
                        mountPath = "/usr/local/etc/haproxy/haproxy.cfg";
                        subPath = "haproxy.cfg";
                        readOnly = true;
                      }
                      {
                        name = "config";
                        mountPath = "/usr/local/etc/haproxy/minecraft.lua";
                        subPath = "minecraft.lua";
                        readOnly = true;
                      }
                    ];
                  }
                ];
                volumes = [
                  {
                    name = "config";
                    configMap.name = "minecraft-haproxy";
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
            name = "minecraft-haproxy";
            namespace = namespace;
          };
          spec = {
            type = "LoadBalancer";
            selector = haproxyLabels;
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
