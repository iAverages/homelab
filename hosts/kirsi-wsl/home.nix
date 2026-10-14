{
  home = {
    username = "dan";
    homeDirectory = "/home/dan";
    stateVersion = "24.05";
  };

  packages.cli.enable = true;

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
  };
}
