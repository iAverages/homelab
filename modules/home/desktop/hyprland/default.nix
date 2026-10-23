{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.desktop.hyprland;
  scripts = import ./scripts.nix {
    inherit pkgs;
    tokenFile = config.sops.secrets.avrgApiToken.path;
  };

  lua = lib.generators.mkLuaInline;
  toLua = lib.generators.toLua {};

  appCommand = app:
    lib.escapeShellArgs ([(lib.getExe pkgs.${app.package})] ++ (app.args or []));
  uwsmApp = command: "uwsm app -- ${command}";
  foregroundApplications = builtins.filter (app: !(app.background or false)) cfg.applications;
  backgroundApplications = builtins.filter (app: app.background or false) cfg.applications;
  startupCommands = map (app: uwsmApp (appCommand app)) foregroundApplications;

  monitorOutputName = name:
    if name == " "
    then ""
    else name;

  mkMonitors = monitors: let
    formatMonitor = name: cfg: let
      res = cfg.res or "preferred";
      hertz =
        if cfg?hertz
        then "@${cfg.hertz}"
        else "";
      pos = cfg.pos or "auto";
      scale = cfg.scale or "1";
    in
      {
        output = monitorOutputName name;
        mode = "${res}${hertz}";
        position = pos;
        inherit scale;
      }
      // lib.optionalAttrs (cfg ? transform) {
        inherit (cfg) transform;
      };
  in
    builtins.attrValues (builtins.mapAttrs formatMonitor monitors);

  mkWorkspaceRules = monitors:
    monitors
    |> builtins.mapAttrs (
      monitorName: monitorCfg: let
        output = monitorOutputName monitorName;
      in
        if output == ""
        then []
        else
          monitorCfg.hyprland.workspaces
          |> map (ws: {
            workspace = toString ws;
            monitor = output;
          })
    )
    |> builtins.attrValues
    |> builtins.concatLists;

  mkBind = keys: dispatcher: {
    _args = [
      keys
      (lua dispatcher)
    ];
  };

  mkBindWithFlags = keys: dispatcher: flags: {
    _args = [
      keys
      (lua dispatcher)
      flags
    ];
  };

  modKey = suffix: lua "mainMod .. \" + ${suffix}\"";
  execCmd = command: "hl.dsp.exec_cmd(${toLua command})";

  wlCopy = lib.getExe' pkgs.wl-clipboard "wl-copy";
  regionScreenshotCommand = "${lib.getExe pkgs.grim} -g \"$(${lib.getExe pkgs.slurp})\" - | ${wlCopy}";

  generateWorkspaceBinds = {
    modifier ? "",
    action ? "focus",
    offset ? 0,
  }:
    lib.range 1 10
    |> (list:
      lib.map (
        i: let
          workspaceNum = i + offset;
          key =
            if i == 10
            then "0"
            else toString i;
          keySuffix =
            if modifier == ""
            then key
            else "${modifier} + ${key}";
          dispatcher =
            if action == "move"
            then "hl.dsp.window.move({ workspace = ${toString workspaceNum} })"
            else "hl.dsp.focus({ workspace = ${toString workspaceNum} })";
        in
          mkBind (modKey keySuffix) dispatcher
      )
      list);
in {
  options.desktop.hyprland = {
    enable = lib.mkEnableOption "hyprland desktop";
    monitors = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      description = "Monitors keyed by output name, a name of \" \" matches any output.";
    };
    applications = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [];
      description = "Applications to start with hyprland.";
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      systemd.enable = false;
      # fix for portals
      package = null;
      portalPackage = null;
      configType = "lua";
      settings = {
        mainMod = {_var = "SUPER";};

        env = [
          {_args = ["XCURSOR_SIZE" "24"];}
          {_args = ["XCURSOR_THEME" "ZhuangFangyi"];}
          {_args = ["HYPRCURSOR_SIZE" "24"];}
          {_args = ["HYPRCURSOR_THEME" "ZhuangFangyi"];}
        ];
        # TODO: make these configurable
        terminal = {_var = "${lib.getExe config.programs.ghostty.package}";};
        fileManager = {_var = "${lib.getExe pkgs.thunar}";};
        menu = {_var = "noctalia msg panel-toggle launcher";};

        sessionMenu = {_var = "noctalia-shell ipc call sessionMenu toggle";};

        on = {
          _args = [
            "hyprland.start"
            (lua ''
              function()
                hl.exec_cmd(${toLua (uwsmApp "nm-applet")})
                for _, command in ipairs(${toLua startupCommands}) do
                  hl.exec_cmd(command)
                end
              end
            '')
          ];
        };

        monitor = mkMonitors cfg.monitors;

        workspace_rule =
          mkWorkspaceRules cfg.monitors
          ++ [
            {
              workspace = "special:magic";
              layout = "scrolling";
            }
          ];

        window_rule =
          map (
            app:
              {
                match = {inherit (app) class;};
                workspace = "${toString app.workspace} silent";
              }
              // (app.rules or {})
          )
          foregroundApplications
          ++ [
            {
              name = "rosemyne-screenshotter-no-animation";
              match = {
                class = "^Rosemyne$";
                title = "^Rosemyne screenshotter$";
              };
              no_anim = true;
            }
            {
              name = "games-allow-tearing";
              match.class = "^(steam_app_.*|gamescope)$";
              immediate = true;
            }
          ];

        config = {
          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            col = {
              active_border = {
                colors = [
                  "rgb(7e22ce)"
                  "rgb(3f1167)"
                ];
                angle = 45;
              };
              inactive_border = "#382D2E";
            };
            layout = "dwindle";
            allow_tearing = true;
          };

          decoration = {
            rounding = 10;

            active_opacity = 1.0;
            inactive_opacity = 1.0;

            blur = {
              enabled = true;
              size = 1;
              passes = 1;
              vibrancy = 0.1696;
            };
          };

          animations = {enabled = true;};

          dwindle = {
            default_split_ratio = 1.0;
            # pseudotile = true;
            preserve_split = true;
          };

          master = {new_status = "master";};

          misc = {
            disable_hyprland_logo = true;
            vrr = 2;
          };
          input = {
            kb_layout = "gb";
            kb_variant = "";
            kb_model = "";
            kb_rules = "";
            follow_mouse = 1;
            sensitivity = -0.35;
            accel_profile = "flat";

            touchpad = {
              natural_scroll = true;
            };
          };

          # fixes issues with nvidia
          xwayland = {force_zero_scaling = true;};

          opengl = {nvidia_anti_flicker = false;};

          debug = {damage_tracking = 0;};

          ecosystem = {no_update_news = true;};
        };

        curve = {
          _args = [
            "myBezier"
            {
              type = "bezier";
              points = [
                [0.05 0.9]
                [0.1 1.05]
              ];
            }
          ];
        };

        animation = [
          {
            leaf = "windows";
            enabled = true;
            speed = 7;
            bezier = "myBezier";
          }
          {
            leaf = "windowsOut";
            enabled = true;
            speed = 7;
            bezier = "default";
            style = "popin 80%";
          }
          {
            leaf = "border";
            enabled = true;
            speed = 10;
            bezier = "default";
          }
          {
            leaf = "borderangle";
            enabled = true;
            speed = 8;
            bezier = "default";
          }
          {
            leaf = "fade";
            enabled = true;
            speed = 7;
            bezier = "default";
          }
          {
            leaf = "workspaces";
            enabled = true;
            speed = 6;
            bezier = "default";
          }
        ];

        bind =
          [
            (mkBind (modKey "Return") "hl.dsp.exec_cmd(terminal)")
            (mkBind (modKey "C") "hl.dsp.window.close()")
            (mkBind (modKey "E") "hl.dsp.exec_cmd(fileManager)")
            (mkBind (modKey "V") ''hl.dsp.window.float({ action = "toggle" })'')
            (mkBind (modKey "R") "hl.dsp.exec_cmd(menu)")
            (mkBind (modKey "I") "hl.dsp.exec_cmd(sessionMenu)")
            (mkBind (modKey "P") "hl.dsp.window.pseudo()")
            (mkBind (modKey "J") ''hl.dsp.layout("togglesplit")'')

            # Move focus with mainMod + arrow keys
            (mkBind (modKey "left") ''hl.dsp.focus({ direction = "l" })'')
            (mkBind (modKey "right") ''hl.dsp.focus({ direction = "r" })'')
            (mkBind (modKey "up") ''hl.dsp.focus({ direction = "u" })'')
            (mkBind (modKey "down") ''hl.dsp.focus({ direction = "d" })'')
            (mkBind (modKey "h") ''hl.dsp.focus({ direction = "l" })'')
            (mkBind (modKey "l") ''hl.dsp.focus({ direction = "r" })'')
            (mkBind (modKey "j") ''hl.dsp.focus({ direction = "u" })'')
            (mkBind (modKey "k") ''hl.dsp.focus({ direction = "d" })'')

            # resize
            (mkBind (modKey "CTRL + h") ''hl.dsp.window.resize({ x = -20, y = 0, relative = true })'')
            (mkBind (modKey "CTRL + l") ''hl.dsp.window.resize({ x = 20, y = 0, relative = true })'')
            (mkBind (modKey "CTRL + j") ''hl.dsp.window.resize({ x = 0, y = -20, relative = true })'')
            (mkBind (modKey "CTRL + k") ''hl.dsp.window.resize({ x = 0, y = 20, relative = true })'')

            # Example special workspace (scratchpad)
            (mkBind (modKey "S") ''hl.dsp.workspace.toggle_special("magic")'')
            (mkBind (modKey "SHIFT + S") ''hl.dsp.window.move({ workspace = "special:magic" })'')

            # Scroll through existing workspaces with mainMod + scroll
            (mkBind (modKey "mouse_down") ''hl.dsp.focus({ workspace = "e+1" })'')
            (mkBind (modKey "mouse_up") ''hl.dsp.focus({ workspace = "e-1" })'')

            (mkBind (modKey "SHIFT + a") (execCmd (lib.getExe scripts.screenshot)))
            (mkBind "CTRL + SHIFT + a" (execCmd regionScreenshotCommand))

            (mkBind (modKey "SHIFT + e") (execCmd (lib.getExe scripts.screenrecord)))
          ]
          # main monitor workspace binds
          ++ generateWorkspaceBinds {}
          # move to workspace
          ++ generateWorkspaceBinds {
            modifier = "SHIFT";
            action = "move";
          }
          # second monitor (normally left) binds
          ++ generateWorkspaceBinds {
            modifier = "CTRL";
            offset = 10;
          }
          # third monitor (normally right) binds
          ++ generateWorkspaceBinds {
            modifier = "ALT";
            offset = 20;
          }
          # Move/resize windows with mainMod + LMB/RMB and dragging
          ++ [
            (mkBindWithFlags (modKey "mouse:272") "hl.dsp.window.drag()" {mouse = true;})
            (mkBindWithFlags (modKey "mouse:273") "hl.dsp.window.resize()" {mouse = true;})
          ];

        # windowrulev2 = "suppressevent maximize, class:.*";
      };
    };

    systemd.user.services =
      backgroundApplications
      |> map (app:
        lib.nameValuePair app.package {
          Unit = {
            Description = app.package;
            PartOf = ["graphical-session.target"];
            After = ["graphical-session.target"];
          };
          Service = {
            ExecStart = appCommand app;
            Restart = "on-failure";
          };
          Install.WantedBy = ["graphical-session.target"];
        })
      |> builtins.listToAttrs;
  };
}
