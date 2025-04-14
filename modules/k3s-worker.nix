# ./modules/k3s-worker.nix
# Takes specialArgs: hostName, k3sControlPlaneAddr
# ASSUMES DEPLOYING TO AN EXISTING NIXOS SYSTEM
{ config, lib, pkgs, specialArgs, ... }:

{ # Start of the single, top-level attribute set

  # --- Settings defined DIRECTLY at the top level ---

  networking.hostName = specialArgs.hostName;

  networking.tailscale.enable = true; # Enable the Tailscale module

  services.k3s = {
    enable = true; # Enable the K3s service itself
    role = "agent";
    serverAddr = "https://${specialArgs.k3sControlPlaneAddr}:6443";
    tokenFile = ../secrets/k3s.token; # Reference fetched secret
  };

  networking.firewall = {
    enable = true; # Explicitly enable firewall
    allowedUDPPorts = [ 8472 ]; # Flannel VXLAN
  };

  # --- fileSystems block REMOVED ---
  # Activation via deploy-rs/nixos-rebuild assumes target system already has mounted filesystems.

  # --- Bootloader Configuration - MUST be kept and MATCH target system ---
  # Assuming target uses GRUB on /dev/sda (common for Hetzner BIOS installs)
  # CHANGE THIS if target uses systemd-boot or different device!
  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/sda";  # Install GRUB updates to the correct disk
      useOSProber = false;
      gfxpayloadBios = "text"; # Often needed for Hetzner BIOS/GPT
    };
    # Ensure systemd-boot is disabled if using GRUB
    systemd-boot.enable = false;
    efi.canTouchEfiVariables = false; # Not needed for BIOS/GRUB
  };

  # --- Base System Configuration ---
  time.timeZone = "America/Denver"; # Set your timezone
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  networking.useDHCP = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    vim wget curl git htop tmux kubectl
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Add your SSH public key for root access if deploying as root
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..." # <<< ADD YOUR PUBLIC KEY HERE
  ];

  system.stateVersion = "24.11"; # Or your preferred version

} # End of the single, top-level attribute set