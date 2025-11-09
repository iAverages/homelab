{
  config,
  lib,
  ...
}: {
  options.system.borgbackup.daily.extraPaths = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Extra paths to include in the daily BorgBackup job.";
    apply = lib.mkMerge;
  };

  services.borgbackup.jobs.daily = {
    repo = config.sops.backup.repo;
    encryption.mode = "repokey";
    encryption.passCommand = "cat ${config.sops.secrets.borgRepoKey.path}";
    compression = "auto,zstd,1";
    startAt = "daily";
    doInit = true;

    extraArgs = [
      # https://docs.hetzner.com/storage/storage-box/access/access-ssh-rsync-borg#borgbackup
      "--remote-path=borg-1.4"
    ];

    paths =
      [
        "/home"
        "/root"
      ]
      ++ config.system.borgbackup.extraPaths;

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
    ];

    environment.BORG_RSH = "ssh -i /root/.ssh/id_ed25519";

    persistentTimer = true;
    postCreate = '''';
  };
}
