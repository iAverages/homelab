{
  config,
  lib,
  ...
}: {
  options.system.borgbackup.daily = {
    enable = lib.mkEnableOption "borg-daily-backup";
    repo = lib.mkOption {
      type = lib.types.str;
      description = "BorgBackup Repo to use for daily backups";
    };
    extraPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to include in the daily BorgBackup job.";
    };
  };

  config.services.borgbackup.jobs.daily = lib.mkIf config.system.borgbackup.daily.enable {
    repo = config.system.borgbackup.daily.repo;
    encryption.mode = "repokey";
    encryption.passCommand = "cat ${config.sops.secrets.borgRepoKey.path}";
    compression = "auto,lzma";
    startAt = "daily";
    # doInit = true;

    extraArgs = [
      # https://docs.hetzner.com/storage/storage-box/access/access-ssh-rsync-borg#borgbackup
      "--remote-path=borg-1.4"
    ];

    paths = lib.mkMerge [
      [
        "/home"
        "/root"
      ]
      config.system.borgbackup.daily.extraPaths
    ];

    prune.keep = {
      within = "1d";
      daily = 7;
      weekly = 4;
      monthly = 12;
    };

    exclude = [
      "**/node_modules"
      "**/.cache"
      "**/.local/share/Steam"
      "/root/sorted"
    ];

    environment.BORG_RSH = "ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no";

    persistentTimer = true;
    postCreate = ''

    '';
  };
}
