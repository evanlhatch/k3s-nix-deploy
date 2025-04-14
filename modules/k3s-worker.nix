# ./modules/k3s-worker.nix
# Defines a COMPLETE minimal K3s Worker (Agent) node.
# Takes specialArgs: hostName, k3sControlPlaneAddr
{ config, pkgs, lib, specialArgs, ... }:

{ # Start of the single, top-level attribute set

  # --- Base System Settings ---
  system.stateVersion = "24.11"; # Or your preferred version
  time.timeZone = "Etc/UTC"; # Set your timezone
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  networking.useDHCP = lib.mkDefault true; # Assumes DHCP provides connectivity

  # SSH Daemon configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password"; # Or "yes" if needed for initial deploy
      PasswordAuthentication = false;
    };
  };
  # Add your SSH public key for root access if deploying as root
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..." # <<< ADD YOUR PUBLIC KEY HERE
  ];

  # Base packages + K8s tools
  environment.systemPackages = with pkgs; [
    git vim curl wget htop tmux tailscale kubectl
  ];

  # Firewall base enablement (rules added below and by other modules)
  networking.firewall.enable = true;
  # -----------------------------------------------------

  # --- Worker Specific Settings ---
  networking.hostName = specialArgs.hostName;

  # --- Tailscale Configuration ---
  services.tailscale = {
    enable = true;
    # For production, use authKeyFile = "/run/secrets/tailscale.key";
    # For testing, we'll use manual authentication
    # authKeyFile = "/run/secrets/tailscale.key";
    extraUpFlags = [ "--ssh" "--accept-routes" "--accept-dns=true" ];
  };
  services.resolved = {
    enable = true; # Ensure resolved is enabled for --accept-dns
    domains = [ "~cinnimon-galaxy.ts.net" ]; # <<< CHANGE TAILNET NAME
  };

  # --- K3s Worker Configuration ---
  services.k3s = {
    enable = true;
    role = "agent";
    serverAddr = "https://${specialArgs.k3sControlPlaneAddr}:6443";
    # For production, use tokenFile = "/run/secrets/k3s.token";
    # For testing, we'll use a dummy token
    token = "dummy-token"; # Using a dummy token for testing
  };

  # --- Consolidated Firewall Settings ---
  networking.firewall = {
    # enable = true; # Already enabled above
    allowedUDPPorts = lib.mkMerge [
      [ 8472 ]                              # K3s Flannel port
      [ config.services.tailscale.port ]    # Tailscale port
    ];
    trustedInterfaces = [ "tailscale0" ];
    checkReversePath = "loose";
    # allowedTCPPorts = [ 10250 ]; # Optional Kubelet port
  };
  # ------------------------------------

  # --- Minimal Filesystem Entry (Dummy for Evaluation) ---
  fileSystems."/" = {
    device = "/dev/null"; # Dummy device to satisfy Nix check
  };
  # -----------------------------------------------------

  # --- Bootloader Configuration ---
  # Ensure this matches the ACTUAL bootloader setup on the target worker machines
  boot.loader.grub = { # Assuming GRUB on /dev/sda
    enable = true;
    device = "/dev/sda"; # <<< VERIFY this device for workers
    useOSProber = false;
    # gfxpayloadBios = "text"; # Uncomment if needed for BIOS/GPT
  };
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;

} # End of the single, top-level attribute set
