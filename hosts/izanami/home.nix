{config, ...}: {
  home = {
    username = "dan";
    homeDirectory = "/home/dan";
    stateVersion = "24.05";
  };

  sops = {
    defaultSopsFile = ../../secrets/personal.yaml;
    age = {
      sshKeyPaths = ["${config.home.homeDirectory}/.ssh/izanami_ed25519"];
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    };
    secrets.avrgApiToken = {};
  };

  desktop.hyprland = {
    enable = true;
    applications = [
      {
        package = "ghostty";
        class = "com.mitchellh.ghostty";
        workspace = 1;
      }
    ];
    monitors." " = {
      scale = "1.6";
      hyprland.workspaces = builtins.genList (i: i + 1) 10;
    };
  };

  packages = {
    cli.enable = true;
    desktop.enable = true;
  };

  programs = {
    home-manager.enable = true;
    git.enable = true;
    jujutsu.enable = true;
    gh.enable = true;
    starship.enable = true;
    atuin.enable = true;
    direnv.enable = true;
    nh.enable = true;
    cargo.enable = true;
    fastfetch.enable = true;
    opencode.enable = true;
    herdr.enable = true;
    yt-dlp.enable = true;
    ghostty.enable = true;
    chromium.enable = true;
    vesktop.enable = true;
    rofi.enable = true;
    waybar.enable = true;
    noctalia.enable = true;
    rclone = {
      enable = true;
      remotes.kurumi = {
        config = {
          type = "sftp";
          host = "192.168.1.202";
          user = "root";
          key_file = "${config.home.homeDirectory}/.ssh/izanami_ed25519";
        };
        mounts."/opt/data" = {
          enable = true;
          mountPoint = "${config.home.homeDirectory}/nas";
          # skip the slow remote df that stalls file managers
          options = {
            disable = "About";
            vfs-cache-max-size = "10G";
          };
        };
      };
    };
  };

  services = {
    mirai.enable = true;
    kdeconnect.enable = true;
  };

  gtk = {
    enable = true;
    cursorTheme.size = 32;
  };
  xdg.mimeApps.enable = true;
  fonts.fontconfig.enable = true;

  xdg.configFile."environment.d/envvars.conf".text = ''
    PATH="${config.home.homeDirectory}/.nix-profile/bin:$PATH";
  '';
}
