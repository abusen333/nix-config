# NixOS Configuration - Clean + Organized (2025)
{ config, pkgs, ... }:

{
  networking.hostId = "deadbeef";

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

#   boot.kernelPackages = pkgs.linuxPackages_latest;
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


  # (Optional) Allow non-root dmesg reading (you used this for debugging)
  boot.kernel.sysctl."kernel.dmesg_restrict" = 0;


  # ============================================================
  # 2) Hardware, Firmware, Graphics
  # ============================================================
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;


  # ============================================================
  # 3) Networking
  # ============================================================
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;


  # ============================================================
  # 4) Time + Locale
  # ============================================================
  time.timeZone = "Asia/Dubai";
  i18n.defaultLocale = "en_US.UTF-8";


  # ============================================================
  # 5) Desktop (KDE Plasma 6)
  # ============================================================
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.defaultSession = "plasma";


  # ============================================================
  # 5b) Hyprland (Wayland session alongside KDE)
  # ============================================================
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
    jack.enable = true;
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
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "kvm" "input" "i2c" "plugdev"  ];
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

  # Make ~/.local/bin available automatically (so openrgb-appimage works)
  environment.sessionVariables = {
    PATH = "$HOME/.local/bin:$PATH";
  };


  # ============================================================
  # 10) Nix Settings (Quality of life)
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
#
  services.hardware.openrgb.enable = false;

  # Installs udev rules + (optionally) starts openrgb daemon
#   services.hardware.openrgb = {
#     enable = true;
#     package = pkgs.openrgb-with-all-plugins;
#     motherboard = "amd";  # good default on your AMD platform
#   };

  # Helps with RAM / SMBus devices, and generally good to have
  hardware.i2c.enable = true;

  # Make sure your user is in the groups typically used by OpenRGB rules


  # ============================================================
  # 12) Apps / Packages / Unfree
  # ============================================================
  nixpkgs.config.allowUnfree = true;
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
    pkgs.libreoffice-qt-fresh
    foliate
    stirling-pdf
    normcap
    zoxide
    vscodium-fhs
    vlc




    fuse
fuse3

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

    # Productivity & Web
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

    # RGB / USB / I2C tools
    appimage-run
    liquidctl
    usbutils
    i2c-tools
    pciutils

    # Hyprland essentials
    waybar
    wofi
    hyprpaper
    hyprlock
    hypridle
    grim
    slurp
    wl-clipboard
    kitty
    mako
    libnotify
    playerctl
    cliphist
    hyprshot



    cmake
    pkg-config
    gcc
    gnumake
    qt6.qtbase
    qt6.qttools
    libusb1
    hidapi

    # Fonts
    nerd-fonts.jetbrains-mono
    font-awesome
  ];

#     nixpkgs.config.permittedInsecurePackages = [
#       "mbedtls-2.28.10"
#     ];

  services.fstrim.enable = true;


  services.ollama = {
  enable = true;

  # solid set for 16GB VRAM: reasoning + science + code
  loadModels = [
    "qwen2.5:7b"
    "llama3.1:8b"
    "qwen2.5-coder:7b"
    "starcoder2:7b"
    "deepseek-r1:1.5b"  # keep if you like it for quick “reasoning style”
  ];
};


  # IMPORTANT:
  # Don't enable the NixOS OpenRGB service if you run the AppImage server.
  # It can start the repo OpenRGB (0.9) and clash with your AppImage (1.0rc2).


  # ============================================================
  # 13) State Version (Do not change)
  # ============================================================
  system.stateVersion = "25.11";
}
