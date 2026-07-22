{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./samba.nix
  ];

  environment.systemPackages = [pkgs.codex];

  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    modesetting.enable = true;
    powerManagement.enable = true;
    moduleParams.nvidia.NVreg_DynamicPowerManagement = "0x02";
    open = false;
  };

  boot.blacklistedKernelModules = ["nouveau"];
  users.users.jellyfin.extraGroups = ["video" "render"];

  services = {
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_SCALING_GOVERNOR_ON_AC = "powersave";

        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 40;

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 40;

        CPU_BOOST_ON_AC = 0;
        CPU_BOOST_ON_BAT = 0;

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      };
    };

    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscaleAuthKey.path;
    };

    syncthing.enable = true;
    nixflix.enable = true;

    external-smtp = {
      enable = true;
      smtp = {
        to = "kurumi-alerts@danielraybone.com";
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
          url = "ssh://git@ssh.github.com:443/iAverages/takina-deployments.git";
          ref.branch = "main";
          secretRef.name = "deployments-git-auth";
        };
      }
      {
        apiVersion = "kustomize.toolkit.fluxcd.io/v1";
        kind = "Kustomization";
        metadata = {
          name = "kurumi";
          namespace = "flux-system";
        };
        spec = {
          interval = "5m";
          retryInterval = "1m";
          timeout = "5m";
          path = "./clusters/kurumi";
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

    udev.extraRules = ''
      ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
      ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
      ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
    '';
  };

  systemd.services.set-hdd-spindown = {
    description = "Set spindown timer for rotational HDDs";
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";

    script = ''
      ${pkgs.hdparm}/bin/hdparm -S 60 $(
        ${pkgs.util-linux}/bin/lsblk -dnpo NAME,ROTA | ${pkgs.gawk}/bin/awk '$2==1 {print $1}'
      )
    '';
  };

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      zfsDataPoolKey = {
        format = "binary";
        sopsFile = ./secrets/zfsDataPoolKey;
      };
      danPassword = {};
      danPasswordNoHash = {};
      familyPasswordNoHash = {};
      tailscaleAuthKey = {};
      tailscaleClientId = {};
      tailscaleClientSecret = {};
      "flux/deployments/identity" = {
        format = "binary";
        sopsFile = ./secrets/flux-deployment-identity;
      };
      "flux/sops-age-key" = {
        format = "binary";
        sopsFile = ./secrets/flux-sops-age-key;
      };
      "pihole/password" = {};
      "zigbee2mqtt/mqtt/password" = {};
      "grafana/username" = {};
      "grafana/password" = {};
      "discordWebhookUrl" = {};
      mailPassword = {};
      borgRepo = {};
      borgRepoKey = {};
      "garage/adminToken" = {};
      tlsCrt = {
        format = "binary";
        sopsFile = ./secrets/ssl/dan-lan.pem;
      };
      tlsKey = {
        format = "binary";
        sopsFile = ./secrets/ssl/dan-lan-key.pem;
      };
      "mie/b2/bucketId" = {};
      "mie/b2/keyId" = {};
      "mie/b2/applicationKey" = {};
      "mie/discordToken" = {};
      "vaultwarden/pushNotifications/installationId" = {};
      "vaultwarden/pushNotifications/installationKey" = {};

      "sonarr/api_key" = {};
      "sonarr/password" = {};
      "radarr/api_key" = {};
      "radarr/password" = {};
      "lidarr/api_key" = {};
      "lidarr/password" = {};
      "prowlarr/api_key" = {};
      "prowlarr/password" = {};
      "indexer-api-keys/DrunkenSlug" = {};
      "indexer-api-keys/NZBFinder" = {};
      "indexer-api-keys/NzbPlanet" = {};
      "jellyfin/dan_password" = {};
      "jellyfin/api_key" = {};
      "qbittorrent/password" = {};
      "seerr/api_key" = {};
      "wireguard/conf" = {
        format = "binary";
        sopsFile = ./secrets/wg.conf;
        restartUnits = ["wg.service" "qbittorrent.service"];
      };
      "sabnzbd/api_key" = {};
      "sabnzbd/nzb_key" = {};
      "usenet/eweka/username" = {};
      "usenet/eweka/password" = {};
      "usenet/newsgroupdirect/username" = {};
      "usenet/newsgroupdirect/password" = {};
    };
    age.sshKeyPaths = ["/root/.ssh/id_ed25519"];
  };

  samba.users = {
    dan = {
      passwordFile = config.sops.secrets.danPasswordNoHash.path;
      allowedShares = ["data" "family"];
    };

    family = {
      passwordFile = config.sops.secrets.familyPasswordNoHash.path;
      allowedShares = ["family"];
    };
  };

  users.groups.family = {};
  users.users.family = {
    isSystemUser = true;
    group = "family";
  };

  system.borgbackup.daily = {
    enable = true;
    repo = "ssh://u474421-sub6@u474421-sub6.your-storagebox.de:23/./backups";
    discordNotificationWebhook = config.sops.secrets.discordWebhookUrl.path;
    borgRemotePath = "borg-1.4";
    uploadRatelimit = "16250";
    extraPaths = [
      "/opt/data"
      "/opt/kubernetes"
      "/var/lib/syncthing"
    ];
  };

  homelab = {
    enable = true;
    domain = "dan.lan";
    flux.enable = true;
    actual-budget.enable = true;
    shiori.enable = true;
    metallb.enable = true;
    metallb.addresses = ["192.168.1.11-192.168.1.149"];
    cnpg.enable = false;
    mysql.enable = false;
    dragonfly.enable = false;
    paperless.enable = true;
    glance.enable = true;
    home-assistant.enable = true;
    zigbee2mqtt = {
      enable = true;
      zigbeeDevice = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_bae0aa2ac8a3ef11b8174cbd61ce3355-if00-port0";
      mqttPassword = config.sops.placeholder."zigbee2mqtt/mqtt/password";
    };
    tailscale = {
      enable = true;
      oauth = {
        clientId = config.sops.placeholder.tailscaleClientId;
        clientSecret = config.sops.placeholder.tailscaleClientSecret;
      };
    };
    monitoring = {
      prometheus-stack = {
        enable = true;
        grafanaUser = config.sops.placeholder."grafana/username";
        grafanaPassword = config.sops.placeholder."grafana/password";
        discordWebhookUrl = config.sops.placeholder.discordWebhookUrl;
        mail = {
          to = "kurumi-alerts@danielraybone.com";
          from = "no-reply@danielraybone.com";
          host = "smtp.protonmail.ch:587";
          username = "no-reply@danielraybone.com";
          password = config.sops.placeholder.mailPassword;
        };
      };
    };

    forgejo = {
      enable = false;
      db.backup.enable = true;
      admin = {
        username = "dan";
        email = "forgejo@danielraybone.com";
        password = config.sops.placeholder.danPasswordNoHash;
      };
    };

    garage = {
      enable = false;
      adminToken = config.sops.placeholder."garage/adminToken";
      storage.dataSize = "100Gi";
    };
    pihole = {
      enable = true;
      dnsIp = "192.168.1.12";
      domain = "pihole.dan.lan";
      password = config.sops.placeholder."pihole/password";
    };
    traefik = {
      ip = "192.168.1.12";
      tls = {
        crt = config.sops.placeholder.tlsCrt;
        key = config.sops.placeholder.tlsKey;
      };
    };
    mie = {
      enable = true;
      b2 = {
        url = "s3.us-west-002.backblazeb2.com";
        bucketId = config.sops.placeholder."mie/b2/bucketId";
        bucketPathPrefix = "uploads/mie";
        bucketName = "dancdn";
        keyId = config.sops.placeholder."mie/b2/keyId";
        applicationKey = config.sops.placeholder."mie/b2/applicationKey";
      };
      discordToken = config.sops.placeholder."mie/discordToken";
      cdnUrl = "https://cdn.avrg.dev/";
    };
    vaultwarden = {
      enable = false;
      pushNotifications = {
        installationId = config.sops.placeholder."vaultwarden/pushNotifications/installationId";
        installationKey = config.sops.placeholder."vaultwarden/pushNotifications/installationKey";
      };
      smtp = {
        from = "no-reply@danielraybone.com";
        host = "smtp.protonmail.ch";
        port = "587";
        username = "no-reply@danielraybone.com";
        password = config.sops.placeholder.mailPassword;
      };
    };
  };

  networking = {
    hostName = "kurumi";
    firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedTCPPorts = [22 443 53 6443];
      allowedUDPPorts = [config.services.tailscale.port];
    };
    hostId = "b1ba14e8";
    useDHCP = true;
    interfaces.enp4s0.useDHCP = true;
    nameservers = ["1.1.1.1" "1.0.0.1"];
  };

  boot.initrd = {
    availableKernelModules = ["r8169"];
    systemd = {
      enable = true;
      services = {
        zfs-initrd-unlock = {
          description = "Unlock ZFS pools in initrd";
          after = ["network-online.target" "sshd.service"];
          before = ["zfs-import-zroot.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            cat <<EOF > /root/.profile
            if pgrep -x "zfs" > /dev/null
            then
              zpool import -a
              zfs load-key -a
              killall zfs
            else
              echo "zfs not running -- maybe the pool is taking some time to load for some unforseen reason."
            fi
            EOF
          '';
          wantedBy = ["initrd.target"];
        };
      };
      network = {enable = true;};
    };
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        hostKeys = [
          /boot/ssh_host_rsa_key
          /boot/ssh_host_ed25519_key
        ];

        ignoreEmptyHostKeys = true;
      };
    };
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
