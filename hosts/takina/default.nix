{config, ...}: {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  dan = true;

  services = {
    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscaleAuthKey.path;
    };

    external-smtp = {
      enable = true;
      smtp = {
        to = "takina-alerts@danielraybone.com";
        from = "no-reply@danielraybone.com";
        host = "smtp.protonmail.ch";
        port = "587";
        username = "no-reply@danielraybone.com";
        passwordFile = config.sops.secrets.mailPassword.path;
      };
    };

    openssh.enable = true;
    config-git-deploy.enable = false;

    k3s.manifests.flux-sync.content = [
      {
        apiVersion = "source.toolkit.fluxcd.io/v1";
        kind = "GitRepository";
        metadata = {
          name = "deployments";
          namespace = "flux-system";
        };
        spec = {
          interval = "1m";
          url = "ssh://git@github.com/iAverages/takina-deployments.git";
          ref.branch = "main";
          secretRef.name = "deployments-git-auth";
        };
      }
      {
        apiVersion = "kustomize.toolkit.fluxcd.io/v1";
        kind = "Kustomization";
        metadata = {
          name = "takina";
          namespace = "flux-system";
        };
        spec = {
          interval = "5m";
          retryInterval = "1m";
          timeout = "5m";
          path = "./clusters/takina";
          prune = true;
          wait = true;
          sourceRef = {
            kind = "GitRepository";
            name = "deployments";
          };
          decryption = {
            provider = "sops";
            secretRef.name = "sops-age";
          };
        };
      }
    ];

    k3s.secrets = [
      {
        metadata = {
          name = "deployments-git-auth";
          namespace = "flux-system";
        };
        data.identity = config.sops.placeholder."flux/deployments/identity";
        stringData = {
          "identity.pub" = builtins.readFile ./flux-deployments.pub;
          known_hosts = builtins.readFile ./github-known-hosts;
        };
      }
      {
        metadata = {
          name = "sops-age";
          namespace = "flux-system";
        };
        data."age.agekey" =
          config.sops.placeholder."flux/sops-age-key";
      }
    ];

    zfs.zed = {
      enableMail = true;
      settings = {
        ZED_EMAIL_ADDR = ["root"];
      };
    };
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      danPassword = {};
      danPasswordNoHash = {};
      tailscaleAuthKey = {};
      tailscaleClientId = {};
      tailscaleClientSecret = {};
      # "grafana/username" = {};
      # "grafana/password" = {};
      "discordWebhookUrl" = {};
      "spqtify/b2_bucket_id" = {};
      "spqtify/b2_application_key_id" = {};
      "spqtify/b2_application_key" = {};
      mailPassword = {};
      borgRepoKey = {};
      "palworld/jame/admin-password" = {};
      "palworld/jame/server-password" = {};
      "palworld/jame/discord-webhook-url" = {};
      "flux/deployments/identity" = {
        format = "binary";
        sopsFile = ./secrets/flux-deployment-identity;
      };
      "flux/sops-age-key" = {
        format = "binary";
        sopsFile = ./secrets/flux-sops-age-key;
      };
      tlsCrt = {
        format = "binary";
        sopsFile = ./secrets/ssl/kirsi-dev.pem;
      };
      tlsKey = {
        format = "binary";
        sopsFile = ./secrets/ssl/kirsi-dev-key.pem;
      };
    };
    age.sshKeyPaths = ["/root/.ssh/takina_ed25519"];
  };

  system.borgbackup.daily = {
    enable = true;
    repo = "ssh://u474421-sub5@u474421-sub5.your-storagebox.de:23/./backups";
    discordNotificationWebhook = config.sops.secrets.discordWebhookUrl.path;
    borgRemotePath = "borg-1.4";
    extraPaths = [
      "/opt"
    ];
  };

  homelab = {
    enable = true;
    domain = "kirsi.dev";
    settings.disableServicelb = false;
    flux.enable = true;
    #   cnpg.enable = true;
    #   mysql.enable = true;
    #   dragonfly.enable = true;

    glance.enable = true;
    tailscale = {
      enable = true;
      oauth = {
        clientId = config.sops.placeholder.tailscaleClientId;
        clientSecret = config.sops.placeholder.tailscaleClientSecret;
      };
    };
    palworld = {
      enable = true;
      servers = {
        jame = {
          dataPath = "/opt/games/palworld/jame";
          storageSize = "30Gi";
          ports.server = 8211;
          service = {
            type = "LoadBalancer";
            exposeQuery = false;
            exposeRestApi = false;
            exposeRcon = false;
          };
          environment = {
            SERVER_NAME = "jame";
            SERVER_DESCRIPTION = "jame";
            PLAYERS = 12;
            COMMUNITY = false;
            AUTO_UPDATE_ENABLED = true;

            ENABLE_PLAYER_LOGGING = true;
            REST_API_ENABLED = true;
            AUTO_REBOOT_ENABLED = true;

            BACKUP_ENABLED = true;
            DELETE_OLD_BACKUPS = true;
            OLD_BACKUP_DAYS = 5;
            ENABLE_PERF_THREADING_ARGS = true;

            PAL_EGG_DEFAULT_HATCHING_TIME = "1.000000";
            EXP_RATE = "2";
          };
          secretEnvironment = {
            ADMIN_PASSWORD =
              config.sops.placeholder."palworld/jame/admin-password";
            SERVER_PASSWORD =
              config.sops.placeholder."palworld/jame/server-password";
            DISCORD_WEBHOOK_URL =
              config.sops.placeholder."palworld/jame/discord-webhook-url";
          };
        };
      };
    };

    minecraft = {
      enable = true;
      defaultServer = "limbo";
      servers = {
        limbo = {
          domain = "limbo.avrg.dev";
          dataPath = "/opt/games/minecraft/limbo";
          storageSize = "2Gi";
          javaVersion = 21;
          environment = {
            TYPE = "CUSTOM";
            CUSTOM_SERVER = "https://ci.loohpjames.com/job/Limbo/lastStableBuild/artifact/target/Limbo-2026.0.2-ALPHA-26.2.jar";
            MEMORY = "1G";
          };
        };

        adham = {
          directPort = 25566;
          dataPath = "/opt/games/minecraft/adham";
          storageSize = "20Gi";
          javaVersion = 17;
          autoRestart = {
            enable = true;
            time = "04:00";
            timeZone = "UTC";
          };
          environment = {
            TYPE = "FABRIC";
            VERSION = "1.20.1";
            FABRIC_LOADER_VERSION = "0.18.4";
            MEMORY = "10G";
          };
        };
      };
    };

    spqtify = {
      enable = false;
      domain = "open.spqtify.com";
      b2 = {
        b2_bucket_id = config.sops.placeholder."spqtify/b2_bucket_id";
        b2_application_key_id = config.sops.placeholder."spqtify/b2_application_key_id";
        b2_application_key = config.sops.placeholder."spqtify/b2_application_key";
      };
    };
    #   # monitoring = {
    #   #   prometheus-stack = {
    #   #     enable = true;
    #   #     grafanaUser = config.sops.placeholder."grafana/username";
    #   #     grafanaPassword = config.sops.placeholder."grafana/password";
    #   #     discordWebhookUrl = config.sops.placeholder.discordWebhookUrl;
    #   #     mail = {
    #   #       to = "kurumi-alerts@danielraybone.com";
    #   #       from = "no-reply@danielraybone.com";
    #   #       host = "smtp.protonmail.ch:587";
    #   #       username = "no-reply@danielraybone.com";
    #   #       password = config.sops.placeholder.mailPassword;
    #   #     };
    #   #   };
    #   # };
    #
    #   # forgejo = {
    #   #   enable = true;
    #   #   db.backup.enable = true;
    #   #   admin = {
    #   #     username = "dan";
    #   #     email = "forgejo@danielraybone.com";
    #   #     password = config.sops.placeholder.danPasswordNoHash;
    #   #   };
    #   # };
    #
    #   # garage = {
    #   #   enable = true;
    #   #   adminToken = config.sops.placeholder."garage/adminToken";
    #   #   storage.dataSize = "100Gi";
    #   # };
    traefik = {
      tls = {
        crt = config.sops.placeholder.tlsCrt;
        key = config.sops.placeholder.tlsKey;
      };
    };
  };

  networking = {
    hostName = "takina";
    firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedTCPPorts = [22 443];
      allowedUDPPorts = [config.services.tailscale.port];
    };
    hostId = "e93c338c";
    useDHCP = true;
    interfaces.enp4s0.useDHCP = true;
    nameservers = ["1.1.1.1" "1.0.0.1"];
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        maxGenerations = 5;
      };
    };
  };

  system.stateVersion = "23.11";
}
