{
  config,
  lib,
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
        sopsFile = ./secrets/ssl/dan.local.crt;
      };
      tlsKey = {
        format = "binary";
        sopsFile = ./secrets/ssl/dan.local.key;
      };
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

  homelab = {
    enable = true;
    domain = "dan.local";
    metallb.addresses = ["192.168.1.11-192.168.1.149"];
    cnpg.enable = true;
    dragonfly.enable = true;
    paperless.enable = true;
    atuin.enable = true;
    monitoring = {
      prometheus-stack = {
        enable = true;
        grafanaUser = config.sops.secrets."grafana/username".path;
        grafanaPasswordFile = config.sops.secrets."grafana/password".path;
        discordWebhookUrl = config.sops.secrets.discordWebhookUrl.path;
        mail = {
          to = "kurumi-alerts@danielraybone.com";
          from = "no-reply@danielraybone.com";
          host = "smtp.protonmail.ch:587";
          username = "no-reply@danielraybone.com";
          password = config.sops.secrets.mailPassword.path;
        };
      };
    };
    pihole = {
      enable = true;
      dnsIp = "192.168.1.11";
      domain = "pihole.dan.local";
      passwordFile = config.sops.secrets."pihole/password".path;
    };
    traefik.tls = {
      crt = config.sops.secrets.tlsCrt.path;
      key = config.sops.secrets.tlsKey.path;
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

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };

  system.stateVersion = "23.11";
}
