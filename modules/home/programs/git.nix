{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.git;
  userEmail = "me@danielraybone.com";
  allowedSignersFile = ".config/git/allowed_signers";
in {
  config = lib.mkIf cfg.enable {
    home.file.${allowedSignersFile}.text =
      ["izanami" "kirsi" "kirsi-wsl"]
      |> map (host: "${userEmail} ${pkgs.lib.getPublicKey host}")
      |> lib.concatStringsSep "\n";

    programs.git = {
      settings = {
        user = {
          name = "iAverages";
          email = userEmail;
        };

        gpg = {
          format = "ssh";
          ssh.allowedSignersFile = "${config.home.homeDirectory}/${allowedSignersFile}";
        };
        init.defaultBranch = "main";
        core.pager = "${pkgs.delta}/bin/delta";
        interactive.diffFilter = "${pkgs.delta}/bin/delta --color-only";
        delta = {
          navigate = true;
        };
        merge.conflictstyle = "zdiff3";
        push = {
          autoSetupRemote = true;
        };
        url."ssh://git@github.com/" = {
          insteadOf = "https://github.com/";
        };
      };
      signing = {
        format = "ssh";
        key = toString ../../../hosts + "/${hostname}/${hostname}_ed25519.pub";
        signByDefault = true;
      };
    };
  };
}
