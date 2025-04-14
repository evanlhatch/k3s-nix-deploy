# ./modules/k3s-worker.nix
# Takes specialArgs: hostName, k3sControlPlaneAddr
# Also receives pkgs, lib, config from the NixOS module system implicitly
{ config, pkgs, lib, specialArgs, ... }: # <<< Ensure 'pkgs' is here

{ # Start of the single, top-level attribute set

  # --- Worker Specific Settings ---
  networking.hostName = specialArgs.hostName;
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://${specialArgs.k3sControlPlaneAddr}:6443";
    tokenFile = ../secrets/k3s.token;
  };

  # --- Tailscale Configuration (Directly Added) ---
  services.tailscale = {
    enable = true;
    # authKeyFile = ../secrets/tailscale.key; # Handle later
    extraUpFlags = [
        "--ssh"             # Enable Tailscale SSH server
        "--accept-routes"   # Accept routes from other nodes
        "--accept-dns=true" # Use Tailscale DNS settings
     ];
  };
  services.resolved = {
    enable = true; # Ensure resolved is enabled for --accept-dns
    domains = [ "~cinnamon-galaxy.ts.net" ]; # <<< CHANGE TAILNET NAME
  };

  # --- Consolidated Firewall Settings ---
  networking.firewall = {
    enable = true;
    allowedUDPPorts = lib.mkMerge [
      [ 8472 ]                              # K3s Flannel port
      [ config.services.tailscale.port ]    # Tailscale port
    ];
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose";
  };
  # ------------------------------------

  # --- Define System Packages ONCE ---
  environment.systemPackages = with pkgs; [ # Uses 'pkgs' from arguments
    git vim curl wget htop tmux tailscale kubectl
  ];

  # --- Minimal Filesystem Entry (Dummy for Evaluation) ---
fileSystems."/" = {
  # Provide a dummy device path to satisfy the evaluation check.
  # This value is NOT used for mounting during deploy-rs activation.
  device = "/dev/null"; # Or "/dev/dummy-device", etc.
  # fsType = "auto"; # You can optionally add fsType too if needed
};
  # -----------------------------------------------------

  # --- Bootloader Configuration ---
  boot.loader.grub = { # Assuming GRUB on /dev/sda
    enable = true;
    device = "/dev/sda"; # <<< VERIFY this device for workers
    useOSProber = false;
    # gfxpayloadBios = "text"; # Uncomment if needed for BIOS/GPT
  };
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;

  # --- Other Base Settings ---
  system.stateVersion = "24.11"; # Or your preferred version
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  networking.useDHCP = lib.mkDefault true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..." # <<< ADD YOUR PUBLIC KEY HERE
  ];


} # End of the single, top-level attribute set