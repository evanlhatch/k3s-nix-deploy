# ./modules/k3s-control.nix
{ config, lib, pkgs, specialArgs, ... }:

{ # Start of the single, top-level attribute set

  # --- Base System Settings (Previously in base.nix) ---
  system.stateVersion = "24.11"; # Or your preferred version
  time.timeZone = "America/Denver"; # Set your timezone
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  networking.useDHCP = lib.mkDefault true; # Usually OK for control plane too

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

  # Base packages defined below

  # Firewall base enablement (rules added below)
  networking.firewall.enable = true;
  # -----------------------------------------------------

  # --- Control Plane Specific Settings ---
  networking.hostName = specialArgs.hostName;
  # Tailscale is enabled via the tailscale.nix module

  # --- K3s Module Configuration ---
  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true; # This is the initializing server
    # For production, use tokenFile = "/run/secrets/k3s.token";
    # For testing, we'll use a dummy token
    token = "dummy-token";
    extraFlags = toString [
      "--disable=servicelb" # If using MetalLB or other LoadBalancer
      "--disable=traefik"   # If using a different Ingress Controller
      # Add other flags as needed
    ];
  };

  # Firewall configuration specific to K3s Control Plane
  networking.firewall = {
    allowedTCPPorts = [
      6443 # Kubernetes API Server
      # Add 2379/2380 only if exposing embedded etcd needed
    ];
    allowedUDPPorts = [
      8472 # Flannel VXLAN (adjust if using a different CNI/backend)
    ];
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

  # Base packages and K8s tools
  environment.systemPackages = with pkgs; [
    git vim curl wget htop tmux tailscale kubectl helm
  ];

} # End of the single, top-level attribute set
