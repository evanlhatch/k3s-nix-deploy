# ./modules/tailscale.nix
{ config, lib, pkgs, ... }:

{
  # --- Option Declaration ---
  # This tells NixOS that this module defines the 'networking.tailscale.enable' option.
  options.networking.tailscale.enable = lib.mkEnableOption "Tailscale service and related networking configuration";

  # --- Configuration Block ---
  # This block applies settings ONLY IF config.networking.tailscale.enable is true elsewhere.
  config = lib.mkIf config.networking.tailscale.enable {

    # Tailscale Service Configuration
    services.tailscale = {
      enable = true; # Enable the actual service

      # Auth Key - Needs provisioning! Either remove or use secrets management (sops-nix/agenix)
      # For now, assuming it's handled externally or manually after deployment.
      # authKeyFile = "/var/lib/tailscale/authkey"; # REMOVE THIS LINE FOR NOW

      # Modern way: Use acceptDNS below, explicitly set forwarding if needed
      # useRoutingFeatures = "server"; # Deprecated style

      # Let Tailscale manage DNS via systemd-resolved
      # Accept routes advertised by other nodes (good for subnets/exit nodes)
      # Enable Tailscale's SSH server capability
      extraUpFlags = [ "--ssh" ];
    };

    # Networking settings related to Tailscale
    networking = {
      # IP forwarding might be needed if advertising routes or acting as exit node
      # ipForwarding.enable = true; # Uncomment if needed

      firewall = {
        # Allow incoming Tailscale UDP port
        allowedUDPPorts = [ config.services.tailscale.port ]; # Default 41641
        # Trust the Tailscale interface for easier inter-node communication
        trustedInterfaces = [ "tailscale0" ];
        # Required for NAT and asymmetric routing scenarios like Tailscale
        checkReversePath = "loose";
      };

      # MagicDNS search domain (replace with your tailnet name)
      search = [ "cinnamon-galaxy.ts.net" ]; # <<< CHANGE TO YOUR TAILNET NAME
    };

    # Ensure systemd-resolved is configured to handle the Tailscale domain
    services.resolved = {
      enable = true; # Ensure systemd-resolved itself is enabled
      domains = [ "~cinnamon-galaxy.ts.net" ]; # <<< CHANGE TO YOUR TAILNET NAME
    };

    # Install only the necessary Tailscale package
    environment.systemPackages = [ pkgs.tailscale ];

  }; # End of config block
}