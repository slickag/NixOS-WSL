{ lib, pkgs, config, ... }: #modulesPath, ... }:
with lib;
let
  syschdemd = import ./syschdemd.nix {
    inherit lib pkgs config;
    defaultUser = "slick";
  };
#  wsl_drop_cache = import ./services/wsl_drop_cache.nix {
#    inherit lib pkgs config;
#  };
in
{  nixpkgs.config.allowUnfree = true;

  imports = [ ./services/wslg-xwayland.nix ]; #./services/wsl-drop-cache.nix ]; #[ "${modulesPath}/profiles/minimal.nix" ];
  nix = {
    autoOptimiseStore = true;
    gc.automatic = true;
    package = pkgs.nixUnstable;
    trustedUsers = [ "root" "slick" ];
    extraOptions = ''
      experimental-features = nix-command flakes ca-references
      builders-use-substitutes = true
    '';
    distributedBuilds = true;
  };
  # WSL is closer to a container than anything else
  boot.isContainer = true;
  boot.enableContainers = true;

  environment.systemPackages = with pkgs; [
    nixFlakes
    git
    bat
    binutils
    coreutils
    curl
    exa
    lsd
    man
    fd
    fzf
    iptables
    procs
    unzip
    vim
    wget
    zip
    zsh
    dos2unix
    tmux
    screen
    wslu
    wsl-open
    socat
  ];

  #fonts = {
    #enableDefaultFonts = true;
    #fonts = [ pkgs.nerdfonts ];
  #};
  programs = {
    # mtr.enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
    };
    bash.enableCompletion = true;
    fuse.userAllowOther = true;
  };

  services = {
    samba.enable = false;
    blueman.enable = false;
    printing.enable = false;
    # wsl-drop-cache.enable = true;
    wslg-xwayland.enable = true;

    journald.extraConfig = ''
      MaxRetentionSec=1week
      SystemMaxUse=200M
    '';
  };

  # Set your time zone.
  time.timeZone = "America/Phoenix";

  boot.cleanTmpDir = true;
  boot.tmpOnTmpfs = true;
  environment.etc.hosts.enable = false;
  environment.etc."resolv.conf".enable = false;
  networking.dhcpcd.enable = false;

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;
  system.autoUpgrade.channel = https://nixos.org/channels/nixos-unstable;

  users.mutableUsers = true;
  users.users.slick = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "lp" "docker" "networkmanager" "audio" "video" "plugdev" "kvm" "cdrom" "bluetooth" ];
  };

  users.users.root = {
    shell = "${syschdemd}/bin/syschdemd";
    #shell = pkgs.zsh;
    # Otherwise WSL fails to login as root with "initgroups failed 5"
    extraGroups = [ "root" ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.etc."wsl.conf" = {
    text = ''
      [automount]
      enabled = true
      options = "metadata,uid=1000,gid=100,umask=0022,fmask=11,case=off"
      crossDistro = true

      [network]
      hostname = NIXOS

      [interop]
      enabled = true
      appendwindowspath = true

      [filesystem]
      umask = 0022

      #[boot]
      #command = /usr/bin/env -i /bin/sh -c 'exec /etc/nixos/wsl2-boot.sh'; /nix/var/nix/profiles/system/sw/bin/sleep 2
    '';
  };

  environment.shellAliases = {
    diff = "diff --color=auto";
    exa = "exa -ga --group-directories-first --time-style=long-iso --color-scale";
    l = "ls -l $*";
    ll = "lsd -AFl --group-dirs first --total-size $*";
    ls = "exa -ahHF $*";
    lt = "ls -T $*";
    tree = "tree -a -I .git --dirsfirst $*";
    nixos-rebuild = "sudo nixos-rebuild $*";
    which-command = "whence";
  };

  systemd.services."user-runtime-dir@".serviceConfig = lib.mkOverride 0 {
    ExecStart = ''/run/wrappers/bin/mount --bind /mnt/wslg/runtime-dir /run/user/%i'';
    ExecStop = ''/run/wrappers/bin/umount /run/user/%i'';
  };
  # Disable systemd units that don't make sense on WSL
  systemd.services."serial-getty@ttyS0".enable = false;
  systemd.services."serial-getty@hvc0".enable = false;
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@".enable = false;

  systemd.services.firewall.enable = false;
  systemd.services.systemd-resolved.enable = false;
  systemd.services.systemd-udevd.enable = false;

  # Don't allow emergency mode, because we don't have a console.
  systemd.enableEmergencyMode = false;
}
