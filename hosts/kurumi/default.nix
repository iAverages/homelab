{
  config,
  pkgs,
  ...
}: let
  publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAUqxOzmjOS0TmJkoV9SQtzo2iOt1JzFJsg84KhPshGb me@danielraybone.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMR9EAOYgfjDJ6knl8kepEdIMyYOpX5bQhaXDiybX9W kirsi-wsl@danielraybone.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjFLBWuH4DV86tNNmGP2ADurDLrLPtO3bCX5U6YElxs izanami@danielraybone.com"
  ];
in {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./samba.nix
  ];

  users.users.root.openssh.authorizedKeys.keys = publicKeys;

  services.tlp = {
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

  powerManagement.powerUpCommands = with pkgs; ''
    ${hdparm}/bin/hdparm -S 60 $(${util-linux}/bin/lsblk -dnp -o name,rota | ${gnugrep}/bin/grep \'.*\\s1\' | ${coreutils}/bin/cut -d \' \' -f 1)
  '';

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      zfsDataPoolKey = {
        format = "binary";
        sopsFile = ./secrets/zfsDataPoolKey;
      };
      danPassword = {};
      danPasswordNoHash = {};
      "pihole/password" = {};
      "grafana/username" = {};
      "grafana/password" = {};
      "discordWebhookUrl" = {};
      mailPassword = {};
      borgRepo = {};
      borgRepoKey = {};
      "garage/rpcSecret" = {};
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
    };
    age.sshKeyPaths = ["/root/.ssh/id_ed25519"];
  };

  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  users.users.dan = {
    isNormalUser = true;
    description = "dan";
    extraGroups = ["networkmanager" "wheel"];
    hashedPasswordFile = config.sops.secrets.danPassword.path;
    openssh.authorizedKeys.keys = publicKeys;
  };

  samba.users.dan = {
    passwordFile = config.sops.secrets.danPasswordNoHash.path;
    allowedShares = ["data"];
  };

  system.borgbackup.daily = {
    enable = true;
    repo = "ssh://u474421-sub6@u474421-sub6.your-storagebox.de:23/./backups";
    discordNotificationWebhook = config.sops.secrets.discordWebhookUrl.path;
    extraPaths = [
      "/opt/data"
      "/opt/kubernetes"
    ];
  };

  services.external-smtp = {
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

  homelab = {
    enable = true;
    domain = "dan.lan";
    metallb.addresses = ["192.168.1.11-192.168.1.149"];
    cnpg.enable = true;
    dragonfly.enable = true;
    paperless.enable = true;
    glance.enable = true;
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
    # garage = {
    #   enable = false;
    #   rpcSecret = config.sops.secrets."garage/rpcSecret".path;
    #   apiHost = "s3.dan.local";
    #   webHost = "garage.dan.local";
    # };
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
        url = "s3.us-west-002.backblazeb2.com0020d4a4136a0090000000031";
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
      enable = true;
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
      allowedTCPPorts = [22 443 53 6443];
    };
    hostId = "b1ba14e8";
    useDHCP = true;
    interfaces.enp4s0.useDHCP = true;
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
        authorizedKeys = publicKeys;
      };
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  services.zfs.zed = {
    enableMail = true;
    settings = {
      ZED_EMAIL_ADDR = ["root"];
    };
  };

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
