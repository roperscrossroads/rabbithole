{
  modulesPath,
  config,
  pkgs,
  ...
}: let
  hostname = "nixos";
  user = "tempuser";
  password = "somepass";

  timeZone = "America/New_York";
  defaultLocale = "en_US.UTF-8";
in {
  imports = [
    # Include the default lxc/lxd configuration.
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  boot.isContainer = true;
  networking.hostName = hostname;

  environment.systemPackages = with pkgs; [
    vim
    bspwm
    sxhkd  # bspwm's hotkey daemon
    xorg.xinit
    xorg.xvfb
    x11vnc
  ];

  services.openssh.enable = true;

  time.timeZone = timeZone;

  i18n = {
    defaultLocale = defaultLocale;
    extraLocaleSettings = {
      LC_ADDRESS = defaultLocale;
      LC_IDENTIFICATION = defaultLocale;
      LC_MEASUREMENT = defaultLocale;
      LC_MONETARY = defaultLocale;
      LC_NAME = defaultLocale;
      LC_NUMERIC = defaultLocale;
      LC_PAPER = defaultLocale;
      LC_TELEPHONE = defaultLocale;
      LC_TIME = defaultLocale;
    };
  };

  users = {
    mutableUsers = false;
    users."${user}" = {
      isNormalUser = true;
      password = password;
      extraGroups = ["wheel"];
    };
  };

  # Enable passwordless sudo.
  security.sudo.extraRules = [
    {
      users = [user];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  # Supress systemd units that don't work because of LXC.
  # https://blog.xirion.net/posts/nixos-proxmox-lxc/#configurationnix-tweak
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  
  services.xserver.enable = true;
  services.xserver.windowManager.bspwm.enable = true;

  # Configure sxhkd separately
  environment.etc."xdg/sxhkd/sxhkdrc".text = ''
    # Example key bindings
    super + Return
        bspc node -t floating
    super + {_,shift + }{h,j,k,l}
        bspc node -p {west,south,north,east}
  '';

  # Start Xvfb on boot
  systemd.services.xvfb = {
    description = "Xvfb Virtual Framebuffer";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xorg.xvfb}/bin/Xvfb :1 -screen 0 1024x768x16";
      Restart = "always";
      User = "root";
    };
  };

  # Start x11vnc on boot
  systemd.services.x11vnc = {
    description = "x11vnc VNC Server";
    after = [ "xvfb.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display :1 -forever -nopw -shared";
      Restart = "always";
      User = "root";
    };
  };

  system.stateVersion = "24.11";
}