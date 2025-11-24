{
  config,
  lib,
  ...
}: let
  inherit (lib) types;
  cfg = config.services.external-smtp;
in {
  options.services.external-smtp = {
    enable = lib.mkEnableOption "external-smtp";
    smtp = {
      to = lib.mkOption {
        type = types.str;
      };
      from = lib.mkOption {
        type = types.str;
      };
      host = lib.mkOption {
        type = types.str;
      };
      port = lib.mkOption {
        type = types.str;
      };
      username = lib.mkOption {
        type = types.str;
      };
      passwordFile = lib.mkOption {
        type = types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc.aliases.text = ''
      root: ${cfg.smtp.to}
    '';

    services.mail.sendmailSetuidWrapper.enable = true;

    programs.msmtp = {
      enable = true;
      setSendmail = true;
      defaults = {
        aliases = "/etc/aliases";
        port = cfg.smtp.port;
        auth = "plain";
        tls = "on";
        tls_starttls = "on";
      };
      accounts = {
        default = {
          inherit (cfg.smtp) host from;
          user = cfg.smtp.username;
          passwordeval = "cat ${cfg.smtp.passwordFile}";
        };
      };
    };
  };
}
