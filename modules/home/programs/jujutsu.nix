{
  config,
  hostname,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.jujutsu;
in {
  config = lib.mkIf cfg.enable {
    programs.jujutsu = {
      settings = {
        user = {
          name = "iAverages";
          email = "me@danielraybone.com";
        };

        aliases = let
          # move x branch to newest change that isnt empty
          move-branch = ["bookmark" "set" "--revision" "(@ ~ empty()) | parents(@ & empty())"];
        in {
          # removes all "orphaned side branches", helps when branches are squashed on github from a PR
          # this will remove all changes not inline with main or not tracked by a bookmark
          cleanup = ["abandon" "-r" "mutable() ~ ::main ~ main:: ~ ::bookmarks()"];
          list-cleanup = ["log" "-r" "mutable() ~ ::main ~ main:: ~ ::bookmarks()"];
          # only shows changes for the current "branch"
          branch = ["log" "-r" "trunk() | (trunk()..connected(@))"];

          inherit move-branch;
          mb = move-branch;
        };

        ui = {
          paginate = "never";
          default-command = "log";
        };

        pager = {
          args = ["${pkgs.delta}/bin/delta"];
        };

        signing = {
          behaviour = "own";
          backend = "ssh";
          key = pkgs.lib.getPublicKey hostname;
          backends.ssh.allowed-signers = "${config.home.homeDirectory}/.config/git/allowed_signers";
        };

        git = {
          sign-on-push = true;
          private-commits = "description('wip:*') | description('private:*')";
        };
      };
    };
  };
}
