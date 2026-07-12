{ config, pkgs, inputs, ... }:

{
  # ============================================================
  # Imports
  # ============================================================
  imports = [
    ./hardware-configuration.nix
  ];

  # ============================================================
  # System Identity
  # ============================================================
  networking.hostName = "nixos";
  networking.hostId = "deadbeef";

  time.timeZone = "Asia/Dubai";
  i18n.defaultLocale = "en_US.UTF-8";

  # ============================================================
  # Boot + Filesystems
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" "ntfs" "exfat" "vfat"];
  boot.zfs.extraPools = [ "data" ];

  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
  services.fstrim.enable = true;

  boot.kernelPackages = pkgs.linuxPackages;
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  fileSystems."/mnt/data" = {
    device = "/data";
    fsType = "none";
    options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/data" ];
  };



  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "acpi_enforce_resources=lax"
    "btusb.enable_autosuspend=0"
    "usbcore.autosuspend=-1"
    "bluetooth.disable_ertm=1"
  ];

  boot.kernelModules = [
    "kvm-amd"
    "i2c-dev"
    "i2c-piix4"
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  boot.extraModprobeConfig = ''
    options rtw89_core disable_ps_mode=Y
    options rtw89_pci disable_aspm_l1=Y disable_aspm_l1ss=Y disable_clkreq=Y

    options btusb enable_autosuspend=0 reset=0
    options bluetooth disable_ertm=1

    options rtw89_core disable_lps_deep=Y
    options cfg80211 ieee80211_regdom=AE
  '';

  boot.kernel.sysctl."kernel.dmesg_restrict" = 0;


  # ============================================================
  # Hardware / Firmware / Graphics
  # ============================================================
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.i2c.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      mesa
      libva
      vulkan-loader
    ];
  };
   services.udisks2.enable = true;
   services.fwupd.enable = true;

  # ============================================================
  # Networking + Firewall
  # ============================================================
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi = {
    powersave = false;
    scanRandMacAddress = false;
  };

  networking.firewall.enable = true;

  networking.firewall.allowedTCPPorts = [
    8095
    8222
    9925
    8096
    9000
  ];

  networking.firewall.allowedTCPPortRanges = [
    { from = 1714; to = 1764; }
  ];

  # networking.firewall.allowedUDPPortRanges = [
  #   { from = 1714; to = 1764; }
  # ];

  networking.firewall.interfaces."virbr0" = {
    allowedTCPPorts = [ 445 139 ];
    allowedUDPPorts = [ 137 138 ];
  };

  programs.kdeconnect.enable = true;
  services.tailscale.enable = true;
# ============================================================
# Bluetooth
# ============================================================
hardware.bluetooth = {
  enable = false;
  powerOnBoot = true;
};

services.blueman.enable = false;

# ============================================================
# Audio / PipeWire
# ============================================================
services.printing.enable = true;

security.rtkit.enable = true;

services.pipewire = {
  enable = true;

  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
  jack.enable = true;

  extraConfig.pipewire."92-quality" = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 256;
      "default.clock.min-quantum" = 256;
      "default.clock.max-quantum" = 512;
    };
  };

  wireplumber = {
    enable = true;

    extraConfig = {
      "10-bluez" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
        };
      };

      "11-bluetooth-policy" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };

      "disable-bt-mic" = {
        "monitor.bluez.rules" = [
          {
            matches = [
              { "node.name" = "~bluez_input.*"; }
            ];
            actions.update-props = {
              "node.disabled" = true;
            };
          }
        ];
      };

      # Mic/input only: lower sensitivity without touching speakers
      # "98-mic-tuning" = {
      #   "monitor.alsa.rules" = [
      #     {
      #       matches = [
      #         { "node.name" = "~alsa_input.*"; }
      #       ];

      #       actions.update-props = {
      #         "audio.volume" = 0.35;
      #         "session.suspend-timeout-seconds" = 0;
      #       };
      #     }
      #   ];
      # };

      # Speaker/output only: keep your existing speaker behavior
      "99-no-suspend" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_output.*"; }
            ];
            actions.update-props = {
              "session.suspend-timeout-seconds" = 0;
            };
          }
        ];
      };
    };
  };
};



# ============================================================
# Desktop / Hyprland / Login Manager
# ============================================================
programs.hyprland.enable = true;
services.displayManager.defaultSession = "hyprland";

services.displayManager.sddm.enable = false;

services.greetd = {
  enable = true;

  settings = {
    default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd hyprland-noctalia";
      user = "greeter";
    };
  };
};

services.libinput.enable = true;

security.pam.services.swaylock = {};



# programs.mango.enable = true;
  # ============================================================
  # Virtualization
  # ============================================================
  virtualisation.docker.enable = true;

 virtualisation.libvirtd = {
   enable = true;
   onBoot = "start";
   onShutdown = "shutdown";

  # qemu = {
  #    package = pkgs.qemu_kvm;
  #    runAsRoot = false;
  #    swtpm.enable = true;
  #    vhostUserPackages = [ pkgs.virtiofsd ];
  #  };
 };

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # ============================================================
  # Users
  # ============================================================
  users.users.a = {
    isNormalUser = true;
    description = "a";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "kvm"
      "input"
      "i2c"
      "plugdev"
      "docker"
      "video"
      "render"
    ];
  };

  users.users.root.shell = pkgs.fish;
  users.defaultUserShell = pkgs.fish;


      # ============================================================
  # Shells
  # ============================================================
  programs.fish = {
    enable = true;
    generateCompletions = true;

    shellAliases = {
      f = "fresh";
      v = "vscodium";

      ll = "eza -lh --group-directories-first --icons";
      la = "eza -lah --group-directories-first --icons";
      cat = "bat";
      grep = "rg";
      find = "fd";
      ".." = "cd ..";
      ns  = "nh os switch";  # Rebuild system using current lock file
      nsu = "nh os switch --update"; # Update packages + rebuild system
      nst = "nh os test"; # Test build temporarily (not added to boot menu)
      nb  = "nh os boot";  # Build system and set as next boot generation
      nsinfo = "nh os info";   # Show system info and generations

      # AI coding workflow
      cc = "claude";
      oc = "opencode";
      ai = "ai-conductor";
      setup-ai = "setup-ai-agents";
      dskey = "set-deepseek-key";
    };


        interactiveShellInit = ''
      zoxide init fish | source
      starship init fish | source

      # If the key exists, expose it in the Anthropic-compatible variable
      # expected by Claude Code when using DeepSeek.
      if set -q DEEPSEEK_API_KEY
        set -gx ANTHROPIC_AUTH_TOKEN $DEEPSEEK_API_KEY
      end
    '';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    ohMyZsh = {
      enable = true;
      plugins = [ "git" "sudo" ];
    };

    shellAliases = {
      f = "fresh";
      v = "codium";
      ll = "eza -lh --group-directories-first --icons";
      la = "eza -lah --group-directories-first --icons";
      cat = "bat";
      grep = "rg";
      find = "fd";
      ".." = "cd ..";
      ns  = "nh os switch";  # Rebuild system using current lock file
      nsu = "nh os switch --update"; # Update packages + rebuild system
      nst = "nh os test"; # Test build temporarily (not added to boot menu)
      nb  = "nh os boot";  # Build system and set as next boot generation
      nsinfo = "nh os info";   # Show system info and generations

      # AI coding workflow
      cc = "claude";
      oc = "opencode";
      ai = "ai-conductor";
      setup-ai = "setup-ai-agents";
      dskey = "set-deepseek-key";
    };

    interactiveShellInit = ''
      eval "$(zoxide init zsh)"

      # Load DeepSeek key if created by the dskey helper.
      [ -f "$HOME/.deepseek-env" ] && source "$HOME/.deepseek-env"

      if [ -n "$DEEPSEEK_API_KEY" ]; then
        export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_API_KEY"
      fi
    '';

    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };


programs.nix-ld.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  environment.pathsToLink = [ "/share/fish" ];
 documentation.man.cache.enable = true;

  environment.sessionVariables = {
    PATH = "$HOME/.local/bin:$PATH";
    NIXOS_OZONE_WL = "1";

    # DeepSeek as Claude Code backend.
    # Keep the actual API key outside this file. Run: dskey
    ANTHROPIC_BASE_URL = "https://api.deepseek.com/anthropic";
    ANTHROPIC_MODEL = "deepseek-v4-pro[1m]";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro[1m]";
    ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro[1m]";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash";
    CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-flash";
    CLAUDE_CODE_EFFORT_LEVEL = "max";
  };

  # ============================================================
  # Nix
  # ============================================================
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  # ============================================================
  # nixpkgs
  # ============================================================

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

programs.steam = {
  enable = true;
};

  nixpkgs.config = {
    allowUnfree = true;
  };

  nixpkgs.overlays = [
    (final: prev:
      let
        disableWeasyChecks = pyFinal: pyPrev: {
          weasyprint = pyPrev.weasyprint.overridePythonAttrs (_old: {
            doCheck = false;
          });
        };
      in
      {
        python3 = prev.python3.override { packageOverrides = disableWeasyChecks; };
        python3Packages = final.python3.pkgs;

        python313 = prev.python313.override { packageOverrides = disableWeasyChecks; };
        python313Packages = final.python313.pkgs;
      })
  ];

  # ============================================================
  # OpenRGB / udev
  # ============================================================
  services.udev.packages = [ pkgs.openrgb ];
  # services.hardware.openrgb.enable = true;
  services.hardware.openrgb = {
  enable = true;
  package = pkgs.openrgb-with-all-plugins;
  motherboard = "amd";
  server.port = 6742;
  startupProfile = "p2";
};

  # ============================================================
  # Samba
  # ============================================================
  services.samba = {
    enable = false;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server role" = "standalone server";
        security = "user";
        "map to guest" = "Bad User";

        interfaces = "lo virbr0";
        "bind interfaces only" = "yes";

        "hosts allow" = "127.0.0.1 192.168.122.";
        "hosts deny" = "0.0.0.0/0";
      };

      trading = {
        path = "/home/a/MEGA/Trading";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "force user" = "a";
        "create mask" = "0664";
        "directory mask" = "2775";
      };
    };
  };

  services.samba-wsdd.enable = true;

  # ============================================================
  # Flatpak
  # ============================================================
  services.flatpak.enable = true;
  services.packagekit.enable = true;

  systemd.services.install-zen-flatpak = {
    description = "Install Zen Browser Flatpak (Flathub)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "flatpak.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
        "${pkgs.flatpak}/bin/flatpak install -y --noninteractive flathub io.github.zen_browser.zen"
      ];
    };
  };

  # ============================================================
  # Services
  # ============================================================

  programs.firefox = {
    enable = true;
  };


  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
    };
  };


  services.ollama = {
    enable = true;
    loadModels = [
      "qwen2.5:7b"
      "llama3.1:8b"
      "qwen2.5-coder:7b"
      "starcoder2:7b"
      "deepseek-r1:1.5b"
    ];
  };



 # Enable Stirling PDF service
services.stirling-pdf = {
  enable = true;
  environment = {
    # 1. Enable the login system
    SECURITY_ENABLELOGIN = "true";

    # 2. Required for Docker-based or fat-jar environments to load security components
    DOCKER_ENABLE_SECURITY = "true";

    # 3. Set your initial admin credentials (change these!)
    # Once you log in, you'll be forced to change the password
    SECURITY_INITIALLOGIN_USERNAME = "a";
    SECURITY_INITIALLOGIN_PASSWORD = "2244";

    SERVER_PORT = "9000";

  };
};



  # ============================================================
  # Packages
  # ============================================================
  environment.variables.EDITOR = "fresh";
  environment.variables.VISUAL = "fresh";




security.polkit.enable = true;


  environment.systemPackages =
    let
      noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      hyprlandNoctaliaStarter = pkgs.writeShellScriptBin "hyprland-noctalia" ''
        set -e
        mkdir -p "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/pictures/screenshots"

        # ── Hyprland Config ──
        if [ ! -f "$HOME/.config/hypr/hyprland.conf" ]; then
          cat > "$HOME/.config/hypr/hyprland.conf" <<'HYPRCFG'
monitor=DP-1,5120x1440@240,0x0,1

env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland;xcb
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1

exec-once = waybar
exec-once = mako
exec-once = /run/current-system/sw/bin/qs -c noctalia-shell
exec-once = swayidle -w timeout 600 'swaylock -f' timeout 900 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = udiskie -t

input {
    kb_layout = us,ara
    kb_options = grp:win_space_toggle
    kb_repeat_rate = 30
    kb_repeat_delay = 250
    follow_mouse = 1
    touchpad { natural_scroll = true; tap-to-click = true }
}

general {
    gaps_in = 5; gaps_out = 10; border_size = 2
    col.active_border = rgba(8ebdffff) rgba(ff6ec7ff) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 8
    blur { enabled = true; size = 4; passes = 2; new_optimizations = true }
    drop_shadow = true; shadow_range = 12
    col.shadow = rgba(1a1a1aee)
}

animations {
    enabled = true
    bezier = smoothOut, 0.36, 0, 0.66, -0.56
    bezier = overshot, 0.4, 0.0, 0.2, 1.2
    animation = windows, 1, 4, smoothOut, popin 80%
    animation = windowsOut, 1, 3, smoothOut
    animation = workspaces, 1, 6, overshot, slide
}

dwindle { pseudotile = true; preserve_split = true }
misc { vfr = true; disable_hyprland_logo = true; disable_splash_rendering = true }

$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, E, exec, dolphin
bind = $mainMod, R, exec, pkill -x rofi || rofi -show drun -show-icons
bind = $mainMod, C, killactive,
bind = $mainMod SHIFT, Q, exec, hyprctl dispatch exit
bind = $mainMod, V, togglefloating,
bind = $mainMod, F, fullscreen, 1
bind = $mainMod, S, togglespecialworkspace,
bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u
bind = $mainMod, J, movefocus, d
bind = $mainMod SHIFT, H, movewindow, l
bind = $mainMod SHIFT, L, movewindow, r
bind = $mainMod SHIFT, K, movewindow, u
bind = $mainMod SHIFT, J, movewindow, d
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPrev, exec, playerctl previous
bindl = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bindl = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
bind = , Print, exec, mkdir -p ~/pictures/screenshots && grim -g "$(slurp)" - | wl-copy && wl-paste > ~/pictures/screenshots/$(date +%Y-%m-%d_%H-%M-%S).png

windowrulev2 = float, class:(org.pulseaudio.pavucontrol)
windowrulev2 = float, class:(blueman-manager)
windowrulev2 = float, title:(Picture-in-Picture)
windowrulev2 = pin, title:(Picture-in-Picture)
HYPRCFG
        fi

        # ── Waybar Config ──
        if [ ! -f "$HOME/.config/waybar/config" ]; then
          cat > "$HOME/.config/waybar/config" <<'WBARCFG'
{
    "layer": "top", "position": "top", "height": 32,
    "margin-top": 6, "margin-left": 8, "margin-right": 8,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["tray","pulseaudio","network","cpu","memory","battery"],
    "hyprland/workspaces": {
        "disable-scroll": true,
        "format": "{icon}",
        "format-icons": {"1":"一","2":"二","3":"三","4":"四","5":"五","6":"六","7":"七","8":"八","9":"九","10":"十"},
        "persistent-workspaces": {"1":[],"2":[],"3":[],"4":[],"5":[]}
    },
    "clock": {"format": "{:%a %d %b  %H:%M}"},
    "tray": {"icon-size": 18},
    "pulseaudio": {"format": "{icon} {volume}%", "format-muted": " {volume}%", "format-icons": {"default":["","",""]}},
    "network": {"format-wifi": " {signalStrength}%", "format-ethernet": " {ifname}", "format-disconnected": " Disconnected"},
    "cpu": {"format": " {usage}%"},
    "memory": {"format": " {}%"},
    "battery": {"format": "{icon} {capacity}%", "format-icons":["",""], "format-charging": " {capacity}%"}
}
WBARCFG
        fi

        if [ ! -f "$HOME/.config/waybar/style.css" ]; then
          cat > "$HOME/.config/waybar/style.css" <<'WBARCSS'
* { font-family: "JetBrains Mono", "Font Awesome 6 Free", sans-serif; font-size: 13px; }
window#waybar { background: rgba(18,18,18,0.85); color: #cdd6f4; border-radius: 8px; }
#workspaces button { color: #6c7086; padding: 2px 8px; border-radius: 4px; }
#workspaces button.active { color: #cdd6f4; background: rgba(137,180,250,0.25); }
#workspaces button:hover { background: rgba(137,180,250,0.15); }
#workspaces button.urgent { color: #f38ba8; }
#clock { padding: 0 12px; }
#pulseaudio, #network, #cpu, #memory, #battery { padding: 0 10px; color: #bac2de; }
#pulseaudio.muted, #battery.critical, #network.disconnected { color: #f38ba8; }
#battery.charging { color: #a6e3a1; }
tooltip { background: rgba(30,30,46,0.95); border: 1px solid rgba(137,180,250,0.3); border-radius: 6px; }
WBARCSS
        fi

        exec Hyprland
      '';

      setDeepSeekKey = pkgs.writeShellScriptBin "set-deepseek-key" ''
        set -euo pipefail

        printf "Paste DeepSeek API key: "
        stty -echo
        read -r KEY
        stty echo
        printf "\n"

        if [ -z "$KEY" ]; then
          echo "No key entered. Nothing changed."
          exit 1
        fi

        mkdir -p "$HOME/.config/fish/conf.d"

        cat > "$HOME/.config/fish/conf.d/deepseek.fish" <<EOF
# Created by set-deepseek-key
set -gx DEEPSEEK_API_KEY '$KEY'
set -gx ANTHROPIC_AUTH_TOKEN '$KEY'
EOF

        cat > "$HOME/.deepseek-env" <<EOF
# Created by set-deepseek-key
export DEEPSEEK_API_KEY='$KEY'
export ANTHROPIC_AUTH_TOKEN='$KEY'
EOF

        chmod 600 "$HOME/.config/fish/conf.d/deepseek.fish" "$HOME/.deepseek-env"

        echo "DeepSeek key saved for fish/zsh. Open a new terminal or run: source ~/.config/fish/conf.d/deepseek.fish"
      '';

      setupAiAgents = pkgs.writeShellScriptBin "setup-ai-agents" ''
        set -euo pipefail

        echo "Setting up Claude Code skills and local memory for user: $USER"

        mkdir -p "$HOME/.claude/skills" "$HOME/.local/bin"

        if [ ! -d "$HOME/.claude/skills/gstack/.git" ]; then
          git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$HOME/.claude/skills/gstack"
        else
          git -C "$HOME/.claude/skills/gstack" pull --ff-only || true
        fi

        if [ -x "$HOME/.claude/skills/gstack/setup" ]; then
          (cd "$HOME/.claude/skills/gstack" && ./setup)
        else
          echo "gstack setup script was not found or not executable."
        fi

        if ! command -v gbrain >/dev/null 2>&1; then
          bun add -g github:garrytan/gbrain
        fi

        export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

        if command -v gbrain >/dev/null 2>&1; then
          if [ ! -d "$HOME/.gbrain" ]; then
            gbrain init --pglite || true
          fi

          if command -v claude >/dev/null 2>&1; then
            if ! claude mcp list 2>/dev/null | grep -q '^gbrain'; then
              claude mcp add gbrain -- gbrain serve || true
            fi
          fi
        else
          echo "gbrain command still not found. Check bun global bin path: ~/.bun/bin"
        fi

        echo "Done. Next: cd into a project, run 'claude', then try /office-hours or /review."
      '';

      aiConductor = pkgs.writeShellScriptBin "ai-conductor" ''
        set -euo pipefail

        PROJECT_DIR="''${1:-$PWD}"
        SESSION_NAME="ai-''$(basename "$PROJECT_DIR" | tr -cd '[:alnum:]_-')"
        LAYOUT_FILE="$(mktemp)"

        cat > "$LAYOUT_FILE" <<EOF
layout {
  pane split_direction="vertical" {
    pane {
      command "fish"
      args "-lc" "cd '$PROJECT_DIR'; echo 'Claude Code + DeepSeek'; claude"
    }
    pane {
      command "fish"
      args "-lc" "cd '$PROJECT_DIR'; echo 'OpenCode / Conductor alternative'; opencode"
    }
  }
  pane size=30 {
    command "fish"
    args "-lc" "cd '$PROJECT_DIR'; git status; echo; echo 'Project shell'; exec fish"
  }
}
EOF

        exec zellij --session "$SESSION_NAME" --layout "$LAYOUT_FILE"
      '';
    in
    with pkgs; [
       setDeepSeekKey
       drawio
      setupAiAgents
      aiConductor
      nodejs_26
      nodejs
      bun
      zellij
      tmux
      eza
      fd
      opencode
      television
      neovim
      git
      kdePackages.dolphin
      wezterm
      wget
      curl
      btop
      fzf
      bashInteractive
      grc
      fresh-editor
      wl-clipboard
      cliphist
      grim
      slurp
      waybar
      rofi
      starship
      nushell
      carapace
      ripgrep
      xclip
      rnote
      libreoffice-qt-fresh
      foliate
      normcap
      vscodium-fhs
      vscode-fhs
      vlc
      fastfetch
      kitty
      cmatrix
      tree

      # rnnoise-plugin
        whisper-cpp
        ffmpeg
        wl-clipboard
        ydotool
        pavucontrol

      nemo-with-extensions


      # ventoy-full-qt
        open-webui
        impression

      alsa-utils

      fuse
      fuse3
      appimage-run
       ntfs3g
       udiskie

      zsh
      zsh-powerlevel10k
      zoxide
      # eza
      bat
      # ripgrep
      # fd
      # atuin
      # dust
      nh
      geany
      uv
    #  python313Packages.marimo
    #  python313Packages.marimo
      # python312Packages.marimo
      rustc
      cargo
      telegram-desktop

      rustPackages.rustfmt
      rustPackages.clippy

      google-chrome
      # brave
      obsidian
      qbittorrent-enhanced
      megasync
      zed-editor
      # onlyoffice-desktopeditors
      stirling-pdf-desktop
      stirling-pdf
      qalculate-gtk
      pdfarranger

      lm_sensors
      dnsmasq
      OVMFFull
      lact
      claude-code
      alacritty-graphics



    # Audio / Screen Recording
    obs-studio
    audacity
    spek
    ffmpeg
    sonobus
    python313Packages.numpy
    python313Packages.pandas
    python313Packages.scipy
    python313Packages.scikit-learn
    python313Packages.torch
    python313Packages.torchaudio
    python313Packages.transformers
    python313Packages.networkx
    qgis
    postgresql_17
    grafana
    python313Packages.mlflow
    mosquitto
    libnotify

      # liquidctl
      usbutils
      i2c-tools
      pciutils
      cmake
      pkg-config
      gcc
      gnumake
      qt6.qtbase
      qt6.qttools
      libusb1
      hidapi
      gimp

      nerd-fonts.jetbrains-mono
      font-awesome


      blueman
      bluez
      bluez-tools
      bluetuith
      pulseaudio

      libva-utils
      vulkan-tools
      radeontop
      openrgb
      # wev

      nautilus
      xwayland-satellite
      mako
      swayidle
      swaylock
      playerctl
      brightnessctl

      noctaliaPkg
      hyprlandNoctaliaStarter
      nix-output-monitor  # Better build output: shows what is building
      nvd                 # Shows package/version differences between generations
      nix-tree            # Explore why a package is in your system
      # nix-index           # Find which package provides a command
      # comma               # Run missing commands quickly with , command
      # nix-search-cli      # Better package search from terminal
      nixfmt  # Format .nix files
      statix              # Lint Nix code
      deadnix             # Find unused Nix code
      direnv              # Auto-load project environments
      nix-direnv          # Faster direnv integration for Nix


      (anki.withAddons [
    ankiAddons.review-heatmap

    (ankiAddons.passfail2.withConfig {
      config = {
        again_button_name = "Fail";
        good_button_name = "Pass";
      };
    })

    ankiAddons.fsrs4anki-helper
    ankiAddons.reviewer-refocus-card
    ankiAddons.adjust-sound-volume

    # Do NOT use this via Nix; it tries to update config
    # ankiAddons.recolor
  ])


    ];


  # ============================================================
  # State Version
  # ============================================================
  system.stateVersion = "25.11";
}
