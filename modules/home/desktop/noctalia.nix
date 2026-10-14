{
  config,
  lib,
  ...
}: let
  cfg = config.programs.noctalia;
  defaultWallpaper = "${cfg.package}/share/noctalia/assets/noctalia-wallpaper.png";
in {
  config = lib.mkIf cfg.enable {
    programs.noctalia = {
      systemd.enable = true;
      settings = {
        settingsVersion = 26;
        appLauncher = {
          customLaunchPrefix = "";
          customLaunchPrefixEnabled = false;
          enableClipPreview = true;
          enableClipboardHistory = false;
          pinnedExecs = [];
          position = "center";
          sortByMostUsed = true;
          terminalCommand = "xterm -e";
          useApp2Unit = false;
          viewMode = "grid";
        };
        audio = {
          cavaFrameRate = 30;
          externalMixer = "pwvucontrol || pavucontrol";
          mprisBlacklist = [];
          preferredPlayer = "";
          visualizerQuality = "high";
          visualizerType = "linear";
          volumeOverdrive = false;
          volumeStep = 5;
        };
        bar = {
          backgroundOpacity = 0.45;
          capsuleOpacity = 1;
          density = "comfortable";
          exclusive = true;
          floating = true;
          marginHorizontal = 0.25;
          marginVertical = 0.25;
          monitors = [];
          order = ["widgets"];
          outerCorners = true;
          position = "top";
          showCapsule = true;
          widgets = {
            center = ["media"];
            end = ["tray" "notifications" "clipboard" "network" "bluetooth" "volume" "brightness" "battery" "date" "clock" "session"];
            margin_edge = 10;
            margin_ends = 10;
            start = ["control-center" "workspaces"];
            left = [
              {
                icon = "rocket";
                id = "CustomButton";
                leftClickExec = "noctalia-shell ipc call launcher toggle";
                leftClickUpdateText = false;
                middleClickExec = "";
                middleClickUpdateText = false;
                parseJson = false;
                rightClickExec = "";
                rightClickUpdateText = false;
                textCollapse = "";
                textCommand = "";
                textIntervalMs = 3000;
                textStream = false;
                wheelDownExec = "";
                wheelDownUpdateText = false;
                wheelExec = "";
                wheelMode = "unified";
                wheelUpExec = "";
                wheelUpUpdateText = false;
                wheelUpdateText = false;
                maxTextLength = {
                  horizontal = 10;
                  vertical = 10;
                };
              }
              {
                characterCount = 2;
                followFocusedScreen = false;
                hideUnoccupied = false;
                id = "Workspace";
                labelMode = "index";
              }
            ];
            right = [
              {
                blacklist = [];
                colorizeIcons = false;
                drawerEnabled = true;
                id = "Tray";
                pinned = [];
              }
              {
                hideWhenZero = true;
                id = "NotificationHistory";
                showUnreadBadge = false;
              }
              {
                displayMode = "onhover";
                id = "Volume";
              }
              {
                colorizeDistroLogo = false;
                colorizeSystemIcon = "primary";
                customIconPath = "";
                enableColorization = true;
                icon = "noctalia";
                id = "ControlCenter";
                useDistroLogo = true;
              }
              {
                customFont = "";
                formatHorizontal = "HH:mm ddd, MMM dd";
                formatVertical = "HH mm - dd MM";
                id = "Clock";
                useCustomFont = false;
                usePrimaryColor = false;
              }
            ];
          };
        };
        brightness = {
          brightnessStep = 5;
          enableDdcSupport = false;
          enforceMinimum = true;
        };
        calendar = {
          cards = [
            {
              enabled = true;
              id = "calendar-header-card";
            }
            {
              enabled = true;
              id = "calendar-month-card";
            }
            {
              enabled = true;
              id = "weather-card";
            }
            {
              enabled = false;
              id = "timer-card";
            }
          ];
        };
        changelog = {
          lastSeenVersion = "";
        };
        colorSchemes = {
          darkMode = true;
          generateTemplatesForPredefined = true;
          manualSunrise = "06:30";
          manualSunset = "18:30";
          matugenSchemeType = "scheme-fruit-salad";
          predefinedScheme = "Noctalia (default)";
          schedulingMode = "off";
          useWallpaperColors = false;
        };
        colors = {
          mError = "#ff6f9b";
          mOnError = "#000000";
          mOnPrimary = "#000000";
          mOnSecondary = "#000000";
          mOnSurface = "#e8d8ff";
          mOnSurfaceVariant = "#b58fff";
          mOnTertiary = "#000000";
          mOutline = "#4c3a70";
          mPrimary = "#b58fff";
          mSecondary = "#c79aff";
          mShadow = "#000000";
          mSurface = "#000000";
          mSurfaceVariant = "#110d1a";
          mTertiary = "#d8b4ff";
        };
        controlCenter = {
          position = "close_to_bar_button";
          shortcuts = {
            left = [
              {
                id = "WiFi";
              }
              {
                id = "Bluetooth";
              }
            ];
            right = [
              {
                id = "PowerProfile";
              }
              {
                id = "NightLight";
              }
            ];
          };
          cards = [
            {
              enabled = true;
              id = "profile-card";
            }
            {
              enabled = true;
              id = "shortcuts-card";
            }
            {
              enabled = true;
              id = "audio-card";
            }
            {
              enabled = true;
              id = "weather-card";
            }
            {
              enabled = true;
              id = "media-sysmon-card";
            }
          ];
        };
        control_center = {
          hidden_tabs = ["weather"];
          shortcuts = [
            {
              type = "wifi";
            }
            {
              type = "bluetooth";
            }
            {
              type = "nightlight";
            }
            {
              type = "notification";
            }
            {
              type = "power_profile";
            }
            {
              type = "audio";
            }
          ];
        };
        desktop_widgets = {
          enabled = false;
        };
        dock = {
          backgroundOpacity = 1;
          colorizeIcons = false;
          displayMode = "auto_hide";
          enabled = false;
          floatingRatio = 1;
          monitors = [];
          onlySameOutput = true;
          pinnedApps = [];
          reserve_space = false;
          size = 1;
          smart_auto_hide = true;
        };
        general = {
          allowPanelsOnScreenWithoutBar = true;
          animationDisabled = false;
          animationSpeed = 1;
          avatarImage = "/home/dan/.face";
          boxRadiusRatio = 1;
          compactLockScreen = false;
          dimmerOpacity = 0;
          enableShadows = true;
          forceBlackScreenCorners = false;
          iRadiusRatio = 1;
          language = "";
          lockOnSuspend = true;
          radiusRatio = 1;
          scaleRatio = 1;
          screenRadiusRatio = 1;
          shadowDirection = "bottom_right";
          shadowOffsetX = 2;
          shadowOffsetY = 3;
          showHibernateOnLockScreen = false;
          showScreenCorners = false;
        };
        hooks = {
          darkModeChange = "";
          enabled = false;
          wallpaperChange = "";
        };
        idle = {
          behavior_order = ["lock" "screen-off" "lock-and-suspend"];
          behavior = {
            lock = {
              action = "lock";
              enabled = true;
              timeout = 600.0;
            };
            lock-and-suspend = {
              action = "lock_and_suspend";
              enabled = false;
              timeout = 900.0;
            };
            screen-off = {
              action = "screen_off";
              enabled = false;
              timeout = 660.0;
            };
          };
        };
        location = {
          analogClockInCalendar = false;
          firstDayOfWeek = -1;
          name = "London";
          showCalendarEvents = true;
          showCalendarWeather = true;
          showWeekNumberInCalendar = false;
          use12hourFormat = false;
          useFahrenheit = false;
          weatherEnabled = true;
          weatherShowEffects = false;
        };
        lockscreen = {
          wallpaper = "/home/dan/.local/share/mirai/wallpaper";
        };
        lockscreen_widgets = {
          enabled = true;
          schema_version = 2;
          widget_order = ["lockscreen-login-box@DP-2" "lockscreen-login-box@DP-1" "lockscreen-login-box@HDMI-A-1" "lockscreen-widget-0000000000000001" "lockscreen-widget-0000000000000002"];
          grid = {
            cell_size = 16;
            major_interval = 4;
            visible = true;
          };
          widget = {
            "lockscreen-login-box@DP-1" = {
              box_height = 196.0;
              box_width = 720.0;
              cx = 540.0;
              cy = 1801.0;
              output = "DP-1";
              placement_height = 1920.0;
              placement_width = 1080.0;
              rotation = 0.0;
              type = "login_box";
              settings = {
                background_color = "surface_variant";
                background_opacity = 0.88;
                background_radius = 12.0;
                center_password_text = false;
                input_opacity = 1.0;
                input_radius = 6.0;
                layout = "regular";
                show_caps_lock = true;
                show_keyboard_layout = true;
                show_login_button = true;
                show_media = true;
                show_session_buttons = true;
                show_unlock_hint = true;
                show_weather = true;
              };
            };
            "lockscreen-login-box@DP-2" = {
              box_height = 150.0;
              box_width = 810.0;
              cx = 960.0;
              cy = 540.0;
              output = "DP-2";
              placement_height = 1080.0;
              placement_width = 1920.0;
              rotation = 0.0;
              type = "login_box";
              settings = {
                background_color = "surface_variant";
                background_opacity = 0.88;
                background_radius = 12.0;
                center_password_text = false;
                input_opacity = 1.0;
                input_radius = 6.0;
                layout = "regular";
                show_caps_lock = true;
                show_keyboard_layout = true;
                show_login_button = true;
                show_media = true;
                show_session_buttons = false;
                show_unlock_hint = false;
                show_weather = true;
              };
            };
            "lockscreen-login-box@HDMI-A-1" = {
              box_height = 196.0;
              box_width = 720.0;
              cx = 960.0;
              cy = 961.0;
              output = "HDMI-A-1";
              placement_height = 1080.0;
              placement_width = 1920.0;
              rotation = 0.0;
              type = "login_box";
              settings = {
                background_color = "surface_variant";
                background_opacity = 0.88;
                background_radius = 12.0;
                center_password_text = false;
                input_opacity = 1.0;
                input_radius = 6.0;
                layout = "regular";
                show_caps_lock = true;
                show_keyboard_layout = true;
                show_login_button = true;
                show_media = true;
                show_session_buttons = true;
                show_unlock_hint = true;
                show_weather = true;
              };
            };
            lockscreen-widget-0000000000000001 = {
              box_height = 0.0;
              box_width = 0.0;
              cx = 960.0;
              cy = 177.0;
              output = "DP-2";
              placement_height = 1080.0;
              placement_width = 1920.0;
              rotation = 0.0;
              type = "clock";
              settings = {
                clock_style = "digital";
              };
            };
            lockscreen-widget-0000000000000002 = {
              box_height = 160.0;
              box_width = 1920.0;
              cx = 958.0;
              cy = 1004.0;
              output = "DP-2";
              placement_height = 1080.0;
              placement_width = 1920.0;
              rotation = 0.0;
              type = "audio_visualizer";
              settings = {
                background_opacity = 0.0;
                bands = 128;
                centered = false;
                color_1 = "primary";
                mirrored = true;
                show_when_idle = false;
              };
            };
          };
        };
        network = {
          wifiEnabled = true;
        };
        nightLight = {
          autoSchedule = true;
          dayTemp = "6500";
          enabled = false;
          forced = false;
          manualSunrise = "06:30";
          manualSunset = "18:30";
          nightTemp = "4000";
        };
        notifications = {
          backgroundOpacity = 0.45;
          criticalUrgencyDuration = 30;
          enableKeyboardLayoutToast = true;
          enabled = true;
          location = "top_right";
          lowUrgencyDuration = 3;
          monitors = ["HDMI-A-1"];
          normalUrgencyDuration = 8;
          overlayLayer = true;
          respectExpireTimeout = false;
        };
        osd = {
          autoHideMs = 2000;
          backgroundOpacity = 1;
          enabled = true;
          enabledTypes = [0 1 2];
          location = "top_right";
          monitors = [];
          overlayLayer = true;
          kinds = {
            media = false;
          };
        };
        screenRecorder = {
          audioCodec = "opus";
          audioSource = "default_output";
          colorRange = "limited";
          directory = "";
          frameRate = 60;
          quality = "very_high";
          showCursor = true;
          videoCodec = "h264";
          videoSource = "portal";
        };
        sessionMenu = {
          countdownDuration = 10000;
          enableCountdown = true;
          position = "center";
          showHeader = true;
          powerOptions = [
            {
              action = "lock";
              command = "";
              countdownEnabled = true;
              enabled = true;
            }
            {
              action = "suspend";
              command = "";
              countdownEnabled = true;
              enabled = true;
            }
            {
              action = "hibernate";
              command = "";
              countdownEnabled = true;
              enabled = true;
            }
            {
              action = "reboot";
              command = "";
              countdownEnabled = true;
              enabled = true;
            }
            {
              action = "logout";
              command = "";
              countdownEnabled = true;
              enabled = true;
            }
            {
              action = "shutdown";
              command = "";
              countdownEnabled = true;
              enabled = true;
            }
          ];
        };
        shell = {
          avatar_path = "/home/dan/.face";
          polkit_agent = true;
          screen_time_enabled = true;
          time_format = "{:%H:%M:%S}";
          launcher = {
            app_grid = true;
            fetch_exchange_rates = false;
          };
          panel = {
            launcher_placement = "attached";
            open_near_click_session = true;
          };
          session = {
            actions = [
              {
                action = "lock";
                countdown_seconds = 0.0;
                enabled = true;
                shortcut = "1";
                variant = "default";
              }
              {
                action = "logout";
                countdown_seconds = 0.0;
                enabled = true;
                shortcut = "2";
                variant = "default";
              }
              {
                action = "lock_and_suspend";
                countdown_seconds = 0.0;
                enabled = false;
                shortcut = "3";
                variant = "default";
              }
              {
                action = "reboot";
                countdown_seconds = 0.0;
                enabled = true;
                shortcut = "4";
                variant = "default";
              }
              {
                action = "shutdown";
                countdown_seconds = 0.0;
                enabled = true;
                shortcut = "5";
                variant = "destructive";
              }
            ];
          };
        };
        systemMonitor = {
          cpuCriticalThreshold = 90;
          cpuPollingInterval = 3000;
          cpuWarningThreshold = 80;
          criticalColor = "";
          diskCriticalThreshold = 90;
          diskPollingInterval = 3000;
          diskWarningThreshold = 80;
          memCriticalThreshold = 90;
          memPollingInterval = 3000;
          memWarningThreshold = 80;
          networkPollingInterval = 3000;
          tempCriticalThreshold = 90;
          tempPollingInterval = 3000;
          tempWarningThreshold = 80;
          useCustomColors = false;
          warningColor = "";
        };
        templates = {
          alacritty = false;
          cava = false;
          code = false;
          discord = false;
          emacs = false;
          enableUserTemplates = false;
          foot = false;
          fuzzel = false;
          ghostty = false;
          gtk = false;
          kcolorscheme = false;
          kitty = false;
          niri = false;
          pywalfox = false;
          qt = false;
          spicetify = false;
          telegram = false;
          vicinae = false;
          walker = false;
          wezterm = false;
        };
        theme = {
          builtin = "Catppuccin";
          community_palette = "Oxocarbon";
          mode = "dark";
          source = "builtin";
          wallpaper_scheme = "m3-content";
        };
        ui = {
          fontDefault = "JetBrainsMono Nerd Font";
          fontDefaultScale = 1;
          fontFixed = "JetBrainsMono Nerd Font";
          fontFixedScale = 1;
          panelBackgroundOpacity = 0.45;
          panelsAttachedToBar = true;
          settingsPanelAttachToBar = false;
          tooltipsEnabled = true;
        };
        wallpaper = {
          default = {
            path = defaultWallpaper;
          };
          directory = "/home/dan/Pictures/Wallpapers";
          enableMultiMonitorDirectories = false;
          enabled = false;
          fillColor = "#000000";
          fillMode = "crop";
          hideWallpaperFilenames = false;
          last = {
            path = defaultWallpaper;
          };
          monitorDirectories = [];
          overviewEnabled = false;
          panelPosition = "follow_bar";
          randomEnabled = false;
          randomIntervalSec = 300;
          recursiveSearch = false;
          setWallpaperOnAllMonitors = true;
          transitionDuration = 1500;
          transitionEdgeSmoothness = 0.05;
          transitionType = "random";
          useWallhaven = false;
          wallhavenCategories = "111";
          wallhavenOrder = "desc";
          wallhavenPurity = "100";
          wallhavenQuery = "";
          wallhavenResolutionHeight = "";
          wallhavenResolutionMode = "atleast";
          wallhavenResolutionWidth = "";
          wallhavenSorting = "relevance";
        };
        widget = {
          audio_visualizer = {
            mirrored = false;
          };
          control-center = {
            glyph = "triangle-inverted-filled";
          };
          media = {
            art_size = 20;
            max_length = 428;
            title_scroll = "on_hover";
          };
          network = {
            anchor = true;
            show_label = false;
          };
        };
      };
    };
  };
}
