{config, ...}: {
  home = {
    username = "dan";
    homeDirectory = "/home/dan";
    stateVersion = "24.05";
  };

  sops = {
    defaultSopsFile = ../../secrets/personal.yaml;
    age = {
      sshKeyPaths = ["${config.home.homeDirectory}/.ssh/kirsi_ed25519"];
      keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    };
    secrets.avrgApiToken = {};
  };

  desktop.hyprland = {
    enable = true;
    applications = [
      {
        package = "streamcontroller";
        args = ["-b"];
        background = true;
      }
      {
        package = "spotify";
        class = "spotify";
        workspace = 1;
      }
      {
        package = "vesktop";
        class = "vesktop";
        workspace = 1;
        rules.suppress_event = "maximize";
      }
      {
        package = "ghostty";
        class = "com.mitchellh.ghostty";
        workspace = 3;
      }
    ];
    monitors = {
      "HDMI-A-1" = {
        res = "1920x1080";
        hertz = "60";
        pos = "0x0";
        hyprland.workspaces = [1] ++ builtins.genList (i: i + 11) 10;
      };
      "DP-2" = {
        res = "1920x1080";
        hertz = "240";
        pos = "1920x0";
        hyprland.workspaces = builtins.genList (i: i + 3) 8;
      };
      "DP-1" = {
        res = "1920x1080";
        hertz = "60";
        pos = "3840x0";
        transform = 3;
        hyprland.workspaces = [2] ++ builtins.genList (i: i + 21) 9;
      };
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
          key_file = "${config.home.homeDirectory}/.ssh/kirsi_ed25519";
        };
        mounts."/opt/data" = {
          enable = true;
          mountPoint = "${config.home.homeDirectory}/nas";
          # skip the slow remote df that stalls file managers
          options.disable = "About";
        };
      };
    };
  };

  services = {
    mirai.enable = true;
    kdeconnect.enable = true;
    jellyfin-mpv-shim.enable = true;
  };

  gtk.enable = true;
  xdg.mimeApps.enable = true;
  fonts.fontconfig.enable = true;

  xdg.configFile."environment.d/envvars.conf".text = ''
    PATH="${config.home.homeDirectory}/.nix-profile/bin:$PATH";
  '';
}
