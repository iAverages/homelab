{
  config,
  lib,
  ...
}: let
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAUqxOzmjOS0TmJkoV9SQtzo2iOt1JzFJsg84KhPshGb me@danielraybone.com";
  sambaUsersMap = {
    dan = {
      hashedPasswordFile = config.sops.secrets.danPassword.path;
    };
  };
in {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./samba.nix
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    publicKey
  ];

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      zfsDataPoolKey = {
        format = "binary";
        sopsFile = ./secrets/zfsDataPoolKey;
      };
      danPassword = {};
      "pihole/password" = {};
      "grafana/username" = {};
      "grafana/password" = {};
      "discordWebhookUrl" = {};
      tlsCrt = {
        format = "binary";
        sopsFile = ./secrets/ssl/dan-local.crt;
      };
      tlsKey = {
        format = "binary";
        sopsFile = ./secrets/ssl/dan-local.key;
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

  system.activationScripts.setSambaPasswords = {
    # Ensure this script runs after sops-nix has decrypted the secrets
    requires = ["sops-nix-activate"];
    text = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: userConfig: ''
        # The password needs to be passed twice
        /run/current-system/sw/bin/printf \
          "$(/run/current-system/sw/bin/cat ${userConfig.hashedPasswordFile})\n$(/run/current-system/sw/bin/cat ${userConfig.hashedPasswordFile})\n" \
          | /run/current-system/sw/bin/smbpasswd -sa ${name}
      '')
      sambaUsersMap);
  };

  homelab = {
    enable = true;
    domain = "dan.local";
    metallb.addresses = ["192.168.1.11-192.168.1.149"];
    cnpg.enable = true;
    monitoring = {
      prometheus-stack = {
        enable = true;
        grafanaUser = config.sops.secrets."grafana/username".path;
        grafanaPasswordFile = config.sops.secrets."grafana/password".path;
        discordWebhookUrl = config.sops.secrets.discordWebhookUrl.path;
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
  };

  boot.initrd = {
    systemd = {
      enable = true;
      services = {
        zfs-initrd-unlock = {
          description = "Unlock ZFS pools in initrd";
          after = ["network-online.target" "sshd.service"];
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
        authorizedKeys = [publicKey];
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

  services.samba = {
    enable = true;
    shares = {
      data = {
        comment = "main data pool";
        browseable = false;
        readOnly = false;
        createMask = "0700";
        directoryMask = "0700";
        validUsers = "dan";
      };
    };
    extraConfig = ''
      security = user
      map to guest = bad user
    '';
  };

  system.stateVersion = "23.11";
}
