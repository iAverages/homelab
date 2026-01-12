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

        # human_readable_size() {
        #     local size_in_bytes="$1"
        #     if [[ -z "$size_in_bytes" || "$size_in_bytes" == "null" ]]; then
        #         ${pkgs.coreutils}/bin/echo "N/A"
        #     else
        #         if [[ "$size_in_bytes" =~ ^[0-9]+$ ]]; then
        #             ${pkgs.coreutils}/bin/numfmt --to=iec-i --suffix=B --format="%8.2f" "$size_in_bytes"
        #         else
        #             ${pkgs.coreutils}/bin/echo "N/A"
        #         fi
        #     fi
        # }
        #
        # REPO_INFO=$(LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 borgWrapper info "''${extraArgs[@]}" --json "$BORG_REPO" 2>&1)
        # echo $REPO_INFO
        # BORG_EXIT_CODE=$?
        #
        # if [ "$BORG_EXIT_CODE" -ne 0 ]; then
        #     ERROR_MESSAGE="Failed to get Borg repository info: $REPO_INFO"
        #     DISCORD_COLOR="16711680"
        #     EMBED_TITLE="❌ Borg Backup Status - FAILED"
        #     EMBED_DESCRIPTION="$ERROR_MESSAGE"
        #     EMBED_FIELDS="[]"
        # else
        #     TOTAL_ORIGINAL_SIZE=$(${pkgs.coreutils}/bin/echo "$REPO_INFO" | ${pkgs.jq}/bin/jq -r '.cache.stats.total_size // "0"')
        #     TOTAL_COMPRESSED_SIZE=$(${pkgs.coreutils}/bin/echo "$REPO_INFO" | ${pkgs.jq}/bin/jq -r '.cache.stats.total_csize // "0"')
        #     TOTAL_DEDUP_SIZE=$(${pkgs.coreutils}/bin/echo "$REPO_INFO" | ${pkgs.jq}/bin/jq -r '.cache.stats.unique_size // "0"')
        #     UNIQUE_CHUNKS=$(${pkgs.coreutils}/bin/echo "$REPO_INFO" | ${pkgs.jq}/bin/jq -r '.cache.stats.total_unique_chunks // "0"')
        #     TOTAL_CHUNKS=$(${pkgs.coreutils}/bin/echo "$REPO_INFO" | ${pkgs.jq}/bin/jq -r '.cache.stats.total_chunks // "0"')
        #
        #     HR_TOTAL_ORIGINAL_SIZE=$(human_readable_size "$TOTAL_ORIGINAL_SIZE")
        #     HR_TOTAL_COMPRESSED_SIZE=$(human_readable_size "$TOTAL_COMPRESSED_SIZE")
        #     HR_TOTAL_DEDUP_SIZE=$(human_readable_size "$TOTAL_DEDUP_SIZE")
        #
        #     ALL_ARCHIVES_LIST=$(LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 borgWrapper list "''${extraArgs[@]}" --json "$BORG_REPO" 2>&1)
        #     echo $ALL_ARCHIVES_LIST
        #     ARCHIVE_LIST_EXIT_CODE=$?
        #
        #     if [ "$ARCHIVE_LIST_EXIT_CODE" -eq 0 ]; then
        #         NUM_ARCHIVES=$(${pkgs.coreutils}/bin/echo "$ALL_ARCHIVES_LIST" | ${pkgs.jq}/bin/jq '.archives | length // 0')
        #     else
        #         ${pkgs.coreutils}/bin/echo "Warning: Failed to get full archive list to count archives. Error: $ALL_ARCHIVES_LIST"
        #         NUM_ARCHIVES="N/A"
        #     fi
        #
        #     LAST_ARCHIVE_LIST_INFO=$(LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 borgWrapper list "''${extraArgs[@]}" --json --last 1 "$BORG_REPO" 2>&1)
        #     LAST_ARCHIVE_LIST_EXIT_CODE=$?
        #
        #     LAST_BACKUP_NAME="N/A"
        #     LAST_BACKUP_TIMESTAMP="N/A"
        #     LAST_BACKUP_ORIGINAL_SIZE="N/A"
        #     LAST_BACKUP_COMPRESSED_SIZE="N/A"
        #     LAST_BACKUP_DEDUP_SIZE="N/A"
        #
        #     if [ "$LAST_ARCHIVE_LIST_EXIT_CODE" -eq 0 ] && [ "$(${pkgs.coreutils}/bin/echo "$LAST_ARCHIVE_LIST_INFO" | ${pkgs.jq}/bin/jq '.archives | length // 0')" -gt 0 ]; then
        #         LAST_BACKUP_NAME=$(${pkgs.coreutils}/bin/echo "$LAST_ARCHIVE_LIST_INFO" | ${pkgs.jq}/bin/jq -r '.archives[0].name // "N/A"')
        #         LAST_BACKUP_TIMESTAMP=$(${pkgs.coreutils}/bin/echo "$LAST_ARCHIVE_LIST_INFO" | ${pkgs.jq}/bin/jq -r '.archives[0].time // "N/A"')
        #
        #         LAST_ARCHIVE_DETAIL_INFO=$(LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 borgWrapper info "''${extraArgs[@]}" --json "$BORG_REPO::$LAST_BACKUP_NAME" 2>&1)
        #         LAST_ARCHIVE_DETAIL_EXIT_CODE=$?
        #
        #         if [ "$LAST_ARCHIVE_DETAIL_EXIT_CODE" -eq 0 ]; then
        #             LAST_BACKUP_ORIGINAL_SIZE=$(${pkgs.coreutils}/bin/echo "$LAST_ARCHIVE_DETAIL_INFO" | ${pkgs.jq}/bin/jq -r '.archives[0].stats.original_size // "0"')
        #             LAST_BACKUP_COMPRESSED_SIZE=$(${pkgs.coreutils}/bin/echo "$LAST_ARCHIVE_DETAIL_INFO" | ${pkgs.jq}/bin/jq -r '.archives[0].stats.compressed_size // "0"')
        #             LAST_BACKUP_DEDUP_SIZE=$(${pkgs.coreutils}/bin/echo "$LAST_ARCHIVE_DETAIL_INFO" | ${pkgs.jq}/bin/jq -r '.archives[0].stats.deduplicated_size // "0"')
        #
        #             HR_LAST_BACKUP_ORIGINAL_SIZE=$(human_readable_size "$LAST_BACKUP_ORIGINAL_SIZE")
        #             HR_LAST_BACKUP_COMPRESSED_SIZE=$(human_readable_size "$LAST_BACKUP_COMPRESSED_SIZE")
        #             HR_LAST_BACKUP_DEDUP_SIZE=$(human_readable_size "$LAST_BACKUP_DEDUP_SIZE")
        #         else
        #             ${pkgs.coreutils}/bin/echo "Warning: Failed to get detailed info for the last archive '$LAST_BACKUP_NAME'. Error: $LAST_ARCHIVE_DETAIL_INFO"
        #         fi
        #     else
        #         ${pkgs.coreutils}/bin/echo "Warning: Could not get information for the last backup archive. Repository might be empty or inaccessible."
        #     fi
        #
        #     DISCORD_COLOR="3066993"
        #     EMBED_TITLE="✅ Borg Backup Status - Repository: $(basename "$BORG_REPO")"
        #     EMBED_DESCRIPTION="Repository statistics and last backup details."
        #     EMBED_FIELDS="[
        #         {
        #             \"name\": \"Total Repository Size\",
        #             \"value\": \"Original: \`$HR_TOTAL_ORIGINAL_SIZE\`\\nCompressed: \`$HR_TOTAL_COMPRESSED_SIZE\`\\nDeduplicated: \`$HR_TOTAL_DEDUP_SIZE\`\",
        #             \"inline\": false
        #         },
        #         {
        #             \"name\": \"Total Chunks (Unique/Total)\",
        #             \"value\": \"\`$UNIQUE_CHUNKS\` / \`$TOTAL_CHUNKS\`\",
        #             \"inline\": true
        #         },
        #         {
        #             \"name\": \"Number of Archives\",
        #             \"value\": \"\`$NUM_ARCHIVES\`\",
        #             \"inline\": true
        #         },
        #         {
        #             \"name\": \"Last Backup Archive\",
        #             \"value\": \"Name: \`$LAST_BACKUP_NAME\`\\nTimestamp: \`$LAST_BACKUP_TIMESTAMP\`\",
        #             \"inline\": false
        #         },
        #         {
        #             \"name\": \"Last Backup Archive Size\",
        #             \"value\": \"Original: \`$HR_LAST_BACKUP_ORIGINAL_SIZE\`\\nCompressed: \`$HR_LAST_BACKUP_COMPRESSED_SIZE\`\\nDeduplicated: \`$HR_LAST_BACKUP_DEDUP_SIZE\`\",
        #             \"inline\": false
        #         }
        #     ]"
        # fi

        PAYLOAD=$(${pkgs.jq}/bin/jq -n \
            --arg title "$EMBED_TITLE" \
            --arg description "$EMBED_DESCRIPTION" \
            --arg color "$DISCORD_COLOR" \
        '{
          "embeds": [
            {
              "title": "Backup complete",
            }
          ]
        }')
            # --argjson fields "$EMBED_FIELDS" \

              # "description": $description,
              # "color": ($color | tonumber),
              # "fields": $fields,


        ${pkgs.curl}/bin/curl -H "Content-Type: application/json" \
             -X POST \
             -d "$PAYLOAD" \
             "$DISCORD_WEBHOOK_URL"

        if [ "$BORG_EXIT_CODE" -ne 0 ]; then
            ${pkgs.coreutils}/bin/echo "failed to send discord notification."
            exit 1
        else
            ${pkgs.coreutils}/bin/echo "discord notification sent"
            exit 0
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
