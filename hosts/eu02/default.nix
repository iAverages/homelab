{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
  ];

  # users.users.root.openssh.authorizedKeys.keys = pkgs.lib.allPublicKeys;

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      danPassword = {};
      danPasswordNoHash = {};
      tailscaleAuthKey = {};
      tailscaleClientId = {};
      tailscaleClientSecret = {};
      tlsCrt = {
        format = "binary";
        sopsFile = ./secrets/ssl/origin-cert.pem;
      };
      tlsKey = {
        format = "binary";
        sopsFile = ./secrets/ssl/private-key.pem;
      };
    };
    age.sshKeyPaths = ["/root/.ssh/id_ed25519"];
  };

  dan = true;

  homelab = {
    enable = true;
    domain = "kirsi.dev";
    glance.enable = true;
    # glance.domain = "glance.kirsi.dev";
    tailscale = {
      enable = true;
      oauth = {
        clientId = config.sops.placeholder.tailscaleClientId;
        clientSecret = config.sops.placeholder.tailscaleClientSecret;
      };
    };
    traefik = {
      ip = "46.224.203.151";
      tls = {
        crt = config.sops.placeholder.tlsCrt;
        key = config.sops.placeholder.tlsKey;
      };
    };
  };

  networking = {
    hostName = "eu02";
    useDHCP = false;
    useNetworkd = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22 443 6443];
    };
  };

  systemd.network = {
    enable = true;

    networks."10-wan" = {
      matchConfig.Name = "en*";

      address = [
        "46.224.203.151/32"
        "2a01:4f8:1c19:ebd::/64"
      ];

      routes = [
        {
          Gateway = "172.31.1.1";
          GatewayOnLink = true;
        }
        {
          Gateway = "fe80::1";
        }
      ];

      dns = [
        "185.12.64.1"
        "185.12.64.2"
        "2a01:4ff:ff00::add:1"
        "2a01:4ff:ff00::add:2"
      ];

      networkConfig = {
        IPv6AcceptRA = false;
      };

      linkConfig = {
        RequiredForOnline = "routable";
      };
    };
  };

  services = {
    config-git-deploy.enable = true;

    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscaleAuthKey.path;
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    loader = {
      grub = {
        enable = true;
        devices = ["nodev"];
      };
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = false;
    };
  };

  system.stateVersion = "23.11";
}
