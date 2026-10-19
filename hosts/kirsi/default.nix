{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "kirsi";

  sops = {
    defaultSopsFile = ../../secrets/personal.yaml;
    age = {
      sshKeyPaths = ["/home/dan/.ssh/kirsi_ed25519"];
      keyFile = "/home/dan/.config/sops/age/keys.txt";
    };
    secrets.danPassword.neededForUsers = true;
  };

  nix.package = pkgs.lixPackageSets.stable.lix;

  boot = {
    initrd.systemd.enable = true;
    plymouth.enable = true;
    tmp.useTmpfs = true;
    loader = {
      efi.canTouchEfiVariables = true;
      limine = {
        enable = true;
        maxGenerations = 10;
        secureBoot.enable = true;
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

  hardware = {
    nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;
    nvidia.open = false;
    bluetooth.enable = true;
    openrazer.enable = true;
  };
  services.xserver.videoDrivers = ["nvidia"];

  locale.gb.enable = true;
  security.sudo-rs.enable = true;
  security.pki.certificateFiles = [../../secrets/dan-lan-ca.crt];

  networking = {
    cloudflare-dns.enable = true;
    resolvconf.enable = false;
    firewall.allowedTCPPorts = [3000 3001 22];
  };

  environment.variables.NH_FLAKE = "/home/dan/homelab";

  users.users.dan = {
    shell = pkgs.zsh;
    extraGroups = ["libvirtd"];
  };

  programs = {
    zsh.enable = true;
    dconf.enable = true;
    hyprland.enable = true;
    thunar.enable = true;
    nix-ld.enable = true;
    gnupg.agent.enable = true;
    steam.enable = true;
    streamcontroller.enable = true;
    coolercontrol.enable = true;
  };

  services = {
    tailscale.enable = true;
    mullvad-vpn.enable = true;
    userborn.enable = true;
    pipewire.enable = true;
    kanata.enable = true;
    printing.enable = true;
    fprintd.enable = true;
    scanner.enable = true;

    dbus = {
      implementation = lib.mkForce "broker";
      packages = [pkgs.dconf];
    };
    openssh = {
      enable = true;
      settings.PermitRootLogin = "no";
    };
  };

  virtualisation = {
    docker.enable = true;
    waydroid.enable = true;
    libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };
  };

  services.udev.packages = [pkgs.via];
  environment.systemPackages = with pkgs; [
    via
    vial
    wine
    ((import inputs.nixpkgs-stable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      }).lutris.override {
        extraLibraries = pkgs: [
          pkgs.gtk4
          pkgs.libadwaita
        ];
      })
    swtpm
    xclip
    virt-manager
  ];
}
