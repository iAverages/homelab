{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.system.borgbackup.daily;
in {
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
    extraExclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra paths to exclude in the daily BorgBackup job.";
    };
    discordNotificationWebhook = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    borgRemotePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
    };
    uploadRatelimit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
    };
  };

  config.services.borgbackup.jobs.daily = lib.mkIf config.system.borgbackup.daily.enable {
    repo = config.system.borgbackup.daily.repo;
    encryption.mode = "repokey";
    encryption.passCommand = "cat ${config.sops.secrets.borgRepoKey.path}";
    compression = "auto,lzma";
    startAt = "daily";
    # doInit = true;

    extraArgs =
      lib.lists.optionals (cfg.borgRemotePath
        != null) ["--remote-path=${cfg.borgRemotePath}"]
      ++ [
        "--debug"
      ];

    extraCreateArgs = lib.lists.optionals (cfg.uploadRatelimit
      != null) [
      "--upload-ratelimit=${cfg.uploadRatelimit}"
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

    postCreate =
      if cfg.discordNotificationWebhook != ""
      then ''
        DISCORD_WEBHOOK_URL="$(${pkgs.coreutils}/bin/cat ${cfg.discordNotificationWebhook})"
        BORG_BIN="${pkgs.borgbackup}/bin/borg"
        JQ_BIN="${pkgs.jq}/bin/jq"
        DATE_BIN="${pkgs.coreutils}/bin/date"
        CUT_BIN="${pkgs.coreutils}/bin/cut"
        TAIL_BIN="${pkgs.coreutils}/bin/tail"
        TR_BIN="${pkgs.coreutils}/bin/tr"
        WC_BIN="${pkgs.coreutils}/bin/wc"
        UNAME_BIN="${pkgs.coreutils}/bin/uname"
        NUMFMT_BIN="${pkgs.coreutils}/bin/numfmt"

        HOSTNAME="$($UNAME_BIN -n)"
        COMPLETED_AT="$($DATE_BIN -u +"%Y-%m-%dT%H:%M:%SZ")"

        archive_json="$($BORG_BIN list --json --last 1 "$BORG_REPO" 2>/dev/null || true)"

        archive_name="$(printf '%s' "$archive_json" | "$JQ_BIN" -r '.archives[0].archive // "unknown"' 2>/dev/null)"
        if [ -z "$archive_name" ] || [ "$archive_name" = "null" ]; then
          archive_name="unknown"
        fi

        archive_stats_json="$($BORG_BIN info --json "$BORG_REPO::$archive_name" 2>/dev/null || true)"

        jq_text() {
          if [ -n "$archive_stats_json" ]; then
            printf '%s' "$archive_stats_json" | "$JQ_BIN" -r "$1 // \"n/a\"" 2>/dev/null || printf 'n/a'
          else
            printf 'n/a'
          fi
        }

        archive_host="$(jq_text '.archives[0].hostname')"
        if [ -z "$archive_host" ] || [ "$archive_host" = "null" ] || [ "$archive_host" = "n/a" ]; then
          archive_host="$HOSTNAME"
        fi

        format_duration() {
          if [ "$1" = "n/a" ] || [ -z "$1" ]; then
            printf 'n/a'
          else
            total_seconds="''${1%%.*}"
            if [ -z "$total_seconds" ]; then
              printf 'n/a'
              return
            fi
            hours="$((total_seconds / 3600))"
            minutes="$(((total_seconds % 3600) / 60))"
            seconds="$((total_seconds % 60))"
            if [ "$hours" -gt 0 ]; then
              printf '%sh %sm %ss' "$hours" "$minutes" "$seconds"
            elif [ "$minutes" -gt 0 ]; then
              printf '%sm %ss' "$minutes" "$seconds"
            else
              printf '%ss' "$seconds"
            fi
          fi
        }

        duration="$(format_duration "$(jq_text '.archives[0].duration')")"

        format_bytes() {
          if [ "$1" = "n/a" ] || [ -z "$1" ]; then
            printf 'n/a'
          else
            "$NUMFMT_BIN" --to=iec-i --suffix=B "$1" 2>/dev/null || printf '%s' "$1"
          fi
        }

        original_size="$(format_bytes "$(jq_text '.archives[0].stats.original_size')")"
        compressed_size="$(format_bytes "$(jq_text '.archives[0].stats.compressed_size')")"
        deduplicated_size="$(format_bytes "$(jq_text '.archives[0].stats.deduplicated_size')")"
        file_count="$(jq_text '.archives[0].stats.nfiles')"
        repo_total_size="$(format_bytes "$(jq_text '.cache.stats.total_size')")"
        repo_deduplicated_size="$(format_bytes "$(jq_text '.cache.stats.unique_size')")"

        archive_count="$($BORG_BIN list --short "$BORG_REPO" 2>/dev/null | $WC_BIN -l | $TR_BIN -d ' ' || true)"
        if [ -z "$archive_count" ]; then
          archive_count="n/a"
        fi

        retention='within 1d, daily 7, weekly 4, monthly 12'
        backup_size_summary="$(printf 'Original: %s\nCompressed: %s\nDeduplicated: %s' \
          "$original_size" \
          "$compressed_size" \
          "$deduplicated_size")"
        repo_usage_summary="$(printf 'Archives: %s\nTotal: %s\nUnique: %s' \
          "$archive_count" \
          "$repo_total_size" \
          "$repo_deduplicated_size")"
        repo_summary="${cfg.repo}"
        ${lib.optionalString (cfg.borgRemotePath != null) ''
          repo_summary="$(printf '%s\nRemote path: %s' "$repo_summary" "${cfg.borgRemotePath}")"
        ''}
        ${lib.optionalString (cfg.uploadRatelimit != null) ''
          repo_summary="$(printf '%s\nUpload ratelimit: %s KiB/s' "$repo_summary" "${cfg.uploadRatelimit}")"
        ''}

        PAYLOAD="$($JQ_BIN -n \
          --arg title "Backup complete" \
          --arg description "New Borg archive created for $archive_host" \
          --arg timestamp "$COMPLETED_AT" \
          --arg footer "Completed at $COMPLETED_AT" \
          --arg archive_name "$archive_name" \
          --arg archive_host "$archive_host" \
          --arg duration "$duration" \
          --arg backup_size_summary "$backup_size_summary" \
          --arg file_count "$file_count" \
          --arg repo_usage_summary "$repo_usage_summary" \
          '{
            embeds: [
              {
                title: $title,
                description: $description,
                color: 3066993,
                timestamp: $timestamp,
                footer: {
                  text: $footer
                },
                fields: [
                  {
                    name: "Archive",
                    value: $archive_name,
                    inline: false
                  },
                  {
                    name: "Host",
                    value: $archive_host,
                    inline: true
                  },
                  {
                    name: "Duration",
                    value: $duration,
                    inline: true
                  },
                  {
                    name: "Files",
                    value: $file_count,
                    inline: true
                  },
                  {
                    name: "This Backup",
                    value: $backup_size_summary,
                    inline: true
                  },
                  {
                    name: "Repo Usage",
                    value: $repo_usage_summary,
                    inline: true
                  }
                ]
              }
            ]
          }')"

        if ${pkgs.curl}/bin/curl -fsS -H "Content-Type: application/json" \
          -X POST \
          -d "$PAYLOAD" \
          "$DISCORD_WEBHOOK_URL"; then
          ${pkgs.coreutils}/bin/echo "discord notification sent"
          exit 0
        else
          ${pkgs.coreutils}/bin/echo "failed to send discord notification."
          exit 1
        fi
      ''
      else "";
  };

  config.environment.systemPackages = lib.mkIf config.system.borgbackup.daily.enable [
    (pkgs.writeShellScriptBin
      "backup"
      ''
        BORG_RSH="ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no" \
        BORG_PASSCOMMAND="cat ${config.sops.secrets.borgRepoKey.path}" \
        BORG_REPO="${cfg.repo}" \
        BORG_REMOTE_PATH="borg-1.4" \
        borg "$@"
      '')
  ];
}
