{config, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
  hardware.nvidia.open = false;
  services.xserver.videoDrivers = ["nvidia"];
  services.scanner.enable = true;

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    secrets = {
      danPassword = {};
    };
    age.sshKeyPaths = ["/home/dan/.ssh/kirsi_ed25519"];
  };

  services.tailscale.enable = true;

  # TODO: do i want to backup daily or just use sync thing?
  # system.borgbackup.daily = {
  #   enable = true;
  #   repo = "ssh://u474421-sub6@u474421-sub6.your-storagebox.de:23/./backups";
  #   discordNotificationWebhook = config.sops.secrets.discordWebhookUrl.path;
  #   extraPaths = [
  #     "/opt/data"
  #     "/opt/kubernetes"
  #   ];
  # };

  networking = {
    hostName = "kirsi";
    firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedTCPPorts = [22];
    };
    hostId = "55b2d328";
    useDHCP = true;
    interfaces.enp4s0.useDHCP = true;
  };

  services.openssh. enable = true;

  nixpkgs.hostPlatform = "x86_64-linux";

  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-uuid/14C4A611C4A5F560";
    fsType = "ntfs3";
    options = ["uid=1000" "nofail"];
  };

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        maxGenerations = 10;
        secureBoot = {
          enable = true;
        };
        extraConfig = ''
          remember_last_entry: yes
        '';
        extraEntries = ''
          /Windows
            protocol: efi
            path: uuid(27f1d4c8-a7d2-4728-8a89-5cc298c0b642):/EFI/Microsoft/Boot/bootmgfw.efi
        '';
      };
    };
  };

  system.stateVersion = "23.11";
}
