{
  lib,
  config,
  ...
}: let
  cfg = config.homelab.zigbee2mqtt;
in {
  options.homelab.zigbee2mqtt = {
    enable = lib.mkEnableOption "zigbee2mqtt";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "zigbee2mqtt.${config.homelab.domain}";
    };

    zigbeeDevice = lib.mkOption {
      type = lib.types.str;
    };

    mqttHost = lib.mkOption {
      type = lib.types.str;
      default = "mosquitto.zigbee2mqtt.svc.cluster.local";
    };

    mqttUsername = lib.mkOption {
      type = lib.types.str;
      default = "zigbee2mqtt";
    };

    mqttPassword = lib.mkOption {
      type = lib.types.str;
    };
  };

  config.services.k3s = lib.mkIf cfg.enable {
    secrets = [
      {
        metadata = {
          name = "zigbee2mqtt-mqtt";
          namespace = "zigbee2mqtt";
        };
        stringData = {
          username = cfg.mqttUsername;
          password = cfg.mqttPassword;
        };
      }
    ];

    manifests.zigbee2mqtt.content = [
      {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = "zigbee2mqtt";
        };
      }
      {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "mosquitto-data";
          namespace = "zigbee2mqtt";
        };
        spec = {
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          resources = {requests = {storage = "1Gi";};};
        };
      }
      {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata = {
          name = "zigbee2mqtt-data";
          namespace = "zigbee2mqtt";
        };
        spec = {
          accessModes = ["ReadWriteOnce"];
          storageClassName = "local-path";
          resources = {requests = {storage = "2Gi";};};
        };
      }
      {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "mosquitto-config";
          namespace = "zigbee2mqtt";
        };
        data = {
          "mosquitto.conf" = ''
            listener 1883 0.0.0.0
            allow_anonymous false
            password_file /mosquitto/auth/passwordfile
            persistence true
            persistence_location /mosquitto/data/
            log_dest stdout
          '';
        };
      }
      {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "zigbee2mqtt-config";
          namespace = "zigbee2mqtt";
        };
        data = {
          "configuration.yaml" = ''
            homeassistant:
              enabled: true
            permit_join: false
            mqtt:
              base_topic: zigbee2mqtt
              server: mqtt://${cfg.mqttHost}:1883
            serial:
              port: /dev/zigbee
              adapter: zstack
            frontend:
              enabled: true
              port: 8080
            advanced:
              network_key: GENERATE
          '';
        };
      }
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "mosquitto";
          namespace = "zigbee2mqtt";
          labels = {"app.kubernetes.io/name" = "mosquitto";};
        };
        spec = {
          replicas = 1;
          strategy = {type = "Recreate";};
          selector = {matchLabels = {"app.kubernetes.io/name" = "mosquitto";};};
          template = {
            metadata = {labels = {"app.kubernetes.io/name" = "mosquitto";};};
            spec = {
              securityContext = {
                fsGroup = 1883;
                fsGroupChangePolicy = "OnRootMismatch";
              };
              initContainers = [
                {
                  name = "init-password-file";
                  image = "eclipse-mosquitto:2";
                  command = [
                    "/bin/sh"
                    "-c"
                    "touch /mosquitto/auth/passwordfile && chown root:root /mosquitto/auth/passwordfile && chmod 0600 /mosquitto/auth/passwordfile && mosquitto_passwd -b /mosquitto/auth/passwordfile \"$MQTT_USERNAME\" \"$MQTT_PASSWORD\" && chown mosquitto:mosquitto /mosquitto/auth/passwordfile && chmod 0600 /mosquitto/auth/passwordfile"
                  ];
                  env = [
                    {
                      name = "MQTT_USERNAME";
                      valueFrom.secretKeyRef = {
                        name = "zigbee2mqtt-mqtt";
                        key = "username";
                      };
                    }
                    {
                      name = "MQTT_PASSWORD";
                      valueFrom.secretKeyRef = {
                        name = "zigbee2mqtt-mqtt";
                        key = "password";
                      };
                    }
                  ];
                  volumeMounts = [
                    {
                      name = "auth";
                      mountPath = "/mosquitto/auth";
                    }
                  ];
                }
              ];
              containers = [
                {
                  name = "mosquitto";
                  image = "eclipse-mosquitto:2";
                  ports = [
                    {
                      name = "mqtt";
                      containerPort = 1883;
                    }
                  ];
                  volumeMounts = [
                    {
                      name = "config";
                      mountPath = "/mosquitto/config/mosquitto.conf";
                      subPath = "mosquitto.conf";
                    }
                    {
                      name = "data";
                      mountPath = "/mosquitto/data";
                    }
                    {
                      name = "auth";
                      mountPath = "/mosquitto/auth";
                      readOnly = true;
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "config";
                  configMap = {name = "mosquitto-config";};
                }
                {
                  name = "data";
                  persistentVolumeClaim = {claimName = "mosquitto-data";};
                }
                {
                  name = "auth";
                  emptyDir = {};
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
          name = "mosquitto";
          namespace = "zigbee2mqtt";
        };
        spec = {
          selector = {"app.kubernetes.io/name" = "mosquitto";};
          ports = [
            {
              name = "mqtt";
              port = 1883;
              targetPort = "mqtt";
            }
          ];
        };
      }
      {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "zigbee2mqtt";
          namespace = "zigbee2mqtt";
          labels = {"app.kubernetes.io/name" = "zigbee2mqtt";};
        };
        spec = {
          replicas = 1;
          strategy = {type = "Recreate";};
          selector = {matchLabels = {"app.kubernetes.io/name" = "zigbee2mqtt";};};
          template = {
            metadata = {labels = {"app.kubernetes.io/name" = "zigbee2mqtt";};};
            spec = {
              securityContext = {
                fsGroup = 1000;
                fsGroupChangePolicy = "OnRootMismatch";
              };
              initContainers = [
                {
                  name = "init-config";
                  image = "busybox:1.36";
                  command = [
                    "/bin/sh"
                    "-c"
                    "if [ ! -f /data/configuration.yaml ]; then cp /defaults/configuration.yaml /data/configuration.yaml; fi"
                  ];
                  volumeMounts = [
                    {
                      name = "data";
                      mountPath = "/data";
                    }
                    {
                      name = "initial-config";
                      mountPath = "/defaults";
                    }
                  ];
                }
              ];
              containers = [
                {
                  name = "zigbee2mqtt";
                  image = "koenkk/zigbee2mqtt:latest";
                  imagePullPolicy = "Always";
                  securityContext = {privileged = true;};
                  ports = [
                    {
                      name = "http";
                      containerPort = 8080;
                    }
                  ];
                  env = [
                    {
                      name = "TZ";
                      value = "Europe/London";
                    }
                    {
                      name = "ZIGBEE2MQTT_CONFIG_MQTT_USER";
                      valueFrom.secretKeyRef = {
                        name = "zigbee2mqtt-mqtt";
                        key = "username";
                      };
                    }
                    {
                      name = "ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD";
                      valueFrom.secretKeyRef = {
                        name = "zigbee2mqtt-mqtt";
                        key = "password";
                      };
                    }
                  ];
                  volumeMounts = [
                    {
                      name = "data";
                      mountPath = "/app/data";
                    }
                    {
                      name = "zigbee";
                      mountPath = "/dev/zigbee";
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "data";
                  persistentVolumeClaim = {claimName = "zigbee2mqtt-data";};
                }
                {
                  name = "initial-config";
                  configMap = {name = "zigbee2mqtt-config";};
                }
                {
                  name = "zigbee";
                  hostPath = {
                    path = cfg.zigbeeDevice;
                    type = "CharDevice";
                  };
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
          name = "zigbee2mqtt";
          namespace = "zigbee2mqtt";
        };
        spec = {
          selector = {"app.kubernetes.io/name" = "zigbee2mqtt";};
          ports = [
            {
              name = "http";
              port = 8080;
              targetPort = "http";
            }
          ];
        };
      }
      {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "zigbee2mqtt";
          namespace = "zigbee2mqtt";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            {
              host = cfg.domain;
              http = {
                paths = [
                  {
                    path = "/";
                    pathType = "Prefix";
                    backend = {
                      service = {
                        name = "zigbee2mqtt";
                        port = {number = 8080;};
                      };
                    };
                  }
                ];
              };
            }
          ];
        };
      }
    ];
  };
}
