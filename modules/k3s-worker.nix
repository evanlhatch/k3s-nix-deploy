# ./modules/k3s-worker.nix
# Takes specialArgs: hostName, k3sControlPlaneAddr
{ config, lib, pkgs, specialArgs, ... }:

{ # Start of the single, top-level attribute set

  # All base settings are now defined directly in this file

  # --- Settings defined DIRECTLY at the top level ---

  networking.hostName = specialArgs.hostName;

  # Tailscale is enabled via the tailscale.nix module

  services.k3s = {
    enable = true; # Enable the K3s service itself
    role = "agent";
    serverAddr = "https://${specialArgs.k3sControlPlaneAddr}:6443";
    # For production, use tokenFile = "/run/secrets/k3s.token";
    # For testing, we'll use a dummy token
    token = "dummy-token";
    # extraFlags = toString [ "--node-label=foo=bar" ];
  };

  networking.firewall = {
    enable = true; # Explicitly enable firewall
    # allowedTCPPorts = [ 10250 ];
    allowedUDPPorts = [ 8472 ]; # Flannel VXLAN
  };

  # --- Disk Configuration (using Disko) ---
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda"; # <<< IMPORTANT: VERIFY/CHANGE this device path!
        content = {
          type = "gpt";
          partitions = {
            ESP = { type = "EF00"; size = "512M"; content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; }; };
            root = { size = "100%"; content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; }; };
          };
        };
      };
    };
  };

  # --- Bootloader Configuration ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Base System Configuration ---
  time.timeZone = "America/Denver"; # Set your timezone
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  networking.useDHCP = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    vim wget curl git htop tmux kubectl
  ];

  virtualisation.libvirtd.enable = true;
  users.users.root.extraGroups = [ "libvirt" ];

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
