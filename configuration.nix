# NixOS Configuration - Clean + Organized (2025)
{ config, pkgs, ... }:

{
  networking.hostId = "deadbeef";

  imports = [
    ./hardware-configuration.nix
  ];

  # ============================================================
  # 1) Boot + Filesystems
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages;

  fileSystems."/mnt/data" = {
    device = "/data";
    fsType = "none";
    options = [ "bind" ];
  };

  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "acpi_enforce_resources=lax"
  ];

  boot.kernelModules = [
    "kvm-amd"
    "i2c-dev"
    "i2c-piix4"
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];

  # Optional: allow non-root dmesg reading
  boot.kernel.sysctl."kernel.dmesg_restrict" = 0;

  services.fstrim.enable = true;


  # ============================================================
  # 2) Hardware, Firmware, Graphics
  # ============================================================
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "bredr";
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  services.blueman.enable = true;
/*

  systemd.services.numlock = {
    description = "Force NumLock on";
    wantedBy = [ "multi-user.target" "sleep.target" ];
    after = [ "systemd-user-sessions.service" ];
    serviceConfig = {
      Type = "oneshot";
      # setleds needs a real TTY, otherwise you'll see ioctl errors
      ExecStart = "${pkgs.bash}/bin/bash -lc '${pkgs.kbd}/bin/setleds -D +num < /dev/tty1'";
    };
  };*/


  # ============================================================
  # 3) Networking
  # ============================================================
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  networking.firewall.enable = true;

  # Stirling-PDF custom port
  networking.firewall.allowedTCPPorts = [
  8095   #   stirling-pdf
  8222    #    vaultwarden
  9925   # mealie
  8096  # jellyfin
  ];


  # ============================================================
  # 4) Time + Locale
  # ============================================================
  time.timeZone = "Asia/Dubai";
  i18n.defaultLocale = "en_US.UTF-8";


  # ============================================================
  # 5) Desktop (KDE Plasma 6) + Hyprland
  # ============================================================
  services.xserver = {
    enable = true;

    xkb = {
      layout = "us,ara";
      options = "grp:win_space_toggle";
    };
  };

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };


  # ============================================================
  # 6) Audio + Printing
  # ============================================================
  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;
    wireplumber.enable = true;

    # ---- Bluetooth: prevent quality drops when an app touches the mic ----
    wireplumber.extraConfig."11-bluetooth-autoswitch" = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };

    # ---- Bluetooth: enable/allow higher quality codecs (if your speaker supports them) ----
    wireplumber.extraConfig."12-bluez-codecs" = {
      "monitor.bluez.properties" = {
        # Better SBC implementation
        "bluez5.enable-sbc-xq" = true;

        # Wideband speech (mostly for headsets; harmless to enable)
        "bluez5.enable-msbc" = true;

        # Hardware volume
        "bluez5.enable-hw-volume" = true;

        # Higher-quality codecs (only used if supported by your device)
        "bluez5.enable-aac" = true;
        "bluez5.enable-aptx" = true;
        "bluez5.enable-aptx-hd" = true;
        "bluez5.enable-ldac" = true;
      };
    };

    # ---- Slightly larger buffers (helps crackles / dropouts) ----
    extraConfig.pipewire."99-buffer" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 1024;
        "default.clock.max-quantum" = 2048;
      };
    };

    extraConfig.pipewire-pulse."99-pulse-buffer" = {
      "pulse.properties" = {
        "pulse.min.req" = "1024/48000";
        "pulse.default.req" = "1024/48000";
        "pulse.max.req" = "2048/48000";
      };
    };
  };



  # ============================================================
  # 7) Virtualization (libvirtd + virt-manager)
  # ============================================================
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "start";
    onShutdown = "shutdown";

    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;


  # ============================================================
  # 8) Users
  # ============================================================
  users.users.a = {
    isNormalUser = true;
    description = "a";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "kvm"
      "input"
      "i2c"
      "plugdev"
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
    shell = pkgs.zsh;
  };

  users.users.root.shell = pkgs.zsh;
  users.defaultUserShell = pkgs.zsh;


  # ============================================================
  # 9) Shells
  # ============================================================
  programs.fish = {
    enable = true;
    generateCompletions = true;
    shellAliases = {
      ll = "ls -l";
      ".." = "cd ..";
    };
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
      ll   = "eza -lh --group-directories-first --icons";
      la   = "eza -lah --group-directories-first --icons";
      cat  = "bat";
      grep = "rg";
      find = "fd";
    };

    interactiveShellInit = ''
      eval "$(zoxide init zsh)"
      # fastfetch
    '';

    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
  };

  environment.pathsToLink = [ "/share/fish" ];
  documentation.man.generateCaches = true;

  environment.sessionVariables = {
    PATH = "$HOME/.local/bin:$PATH";
  };


  # ============================================================
  # 10) Nix Settings
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
  # 11) udev rules (OpenRGB access)
  # ============================================================
  services.udev.extraRules = ''
    # Allow I2C access for users in i2c group
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"

    # Gigabyte RGB Fusion 2 / IT5711 controller (hidraw)
    SUBSYSTEM=="hidraw", ENV{ID_VENDOR_ID}=="048d", ENV{ID_MODEL_ID}=="5711", MODE="0660", GROUP="input"
  '';

  services.udev.packages = [ pkgs.openrgb ];

  # If you run OpenRGB AppImage server, keep this disabled
  services.hardware.openrgb.enable = false;

  hardware.i2c.enable = true;


  # ============================================================
  # 12) nixpkgs config (Unfree + Insecure)
  # ============================================================
  nixpkgs.config = {
    allowUnfree = true;

    # Ventoy is marked insecure in nixpkgs. Whitelist the version(s) you see in the error.
    permittedInsecurePackages = [
    "ventoy-1.1.10"
    "ventoy-qt5-1.1.10"
    "ventoy-full-qt-1.1.10"
    ];
  };

  # IMPORTANT FIX:
  # Stirling-PDF pulls weasyprint; on some nixpkgs snapshots, its tests fail on Python 3.13.
  # This overlay disables weasyprint checks to allow the build to succeed.
  nixpkgs.overlays = [
    (final: prev:
      let
        disableWeasyChecks = pyFinal: pyPrev: {
          weasyprint = pyPrev.weasyprint.overridePythonAttrs (_old: {
            doCheck = false; # skip failing pytest suite
          });
        };
      in
      {
        # If something references pkgs.python3.pkgs.weasyprint
        python3 = prev.python3.override { packageOverrides = disableWeasyChecks; };
        python3Packages = final.python3.pkgs;

        # What your build log shows (Python 3.13.11)
        python313 = prev.python313.override { packageOverrides = disableWeasyChecks; };
        python313Packages = final.python313.pkgs;
      })
  ];



  # ============================================================
  # 13) Stirling-PDF (Service)
  # ============================================================
  services.stirling-pdf = {
    enable = true;

    environment = {
      SERVER_PORT = 8095;

      # If you want to access from other devices on your LAN:
      # SERVER_ADDRESS = "0.0.0.0";
    };
  };


  services.vaultwarden = {
  enable = true;
  config = {
    ROCKET_PORT = 8222;
    SIGNUPS_ALLOWED = false;
  };
};


services.mealie = {
  enable = true;
  port = 9925;
};

/*
  # --- Jellyfin ---
  services.jellyfin = {
    enable = true;
    openFirewall = true;
    user = "a";
    dataDir = "/var/lib/jellyfin";
  };*/

  # ============================================================
  # 14) Ollama
  # ============================================================
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


  # ============================================================
  # 15) n8n
  # ============================================================
  services.n8n = {
    enable = true;
    openFirewall = true;

    environment = {
      N8N_PORT = 5678;
      GENERIC_TIMEZONE = "Asia/Dubai";
      N8N_DIAGNOSTICS_ENABLED = false;
      N8N_VERSION_NOTIFICATIONS_ENABLED = false;
    };
  };


  # ============================================================
  # 16) Apps / Packages
  # ============================================================
  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    # Editors & CLI Tools
    vim
    neovim
    git
    wget
    curl
    btop
    fzf
    grc
    rnote
    libreoffice-qt-fresh
    foliate
    normcap
    vscodium-fhs
    vlc
    kdePackages.isoimagewriter

    # Ventoy GUI variant you chose
    ventoy-full-qt
    gnome-disk-utility
    kdePackages.partitionmanager

    # FUSE (for AppImages etc)
    fuse
    fuse3
    appimage-run

    # Terminal tools
    zsh
    zsh-powerlevel10k
    zoxide
    eza
    bat
    ripgrep
    fd
    fastfetch
    atuin
    dust
    python312Packages.marimo
    kdePackages.yakuake

    # Productivity & Web
    kdePackages.kteatime
    google-chrome
    brave
    obsidian
    qbittorrent-enhanced
    megasync

    # KDE & Hardware
    kdePackages.kdeconnect-kde
    kdePackages.bluedevil

    # Hardware monitoring / health
    lm_sensors
    dnsmasq

    # UEFI firmware package for VMs
    OVMFFull
    lact

    # RGB / USB / I2C tools
    liquidctl
    usbutils
    i2c-tools
    pciutils

    # Build tools
    cmake
    pkg-config
    gcc
    gnumake
    qt6.qtbase
    qt6.qttools
    libusb1
    hidapi

/*

    jellyfin
    jellyfin-web
    jellyfin-ffmpeg
    jellyfin-media-player*/



    # Fonts
    nerd-fonts.jetbrains-mono
    font-awesome
  ];


  # ============================================================
  # 17) State Version (Do not change)
  # ============================================================
  system.stateVersion = "25.11";
}
