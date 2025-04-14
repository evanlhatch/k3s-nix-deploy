{ config, lib, pkgs, ... }: {
  # Enable Tailscale service
  services.tailscale = {
    enable = true;

    # Auto-connect to your tailnet on boot using the auth key
    authKeyFile = "/var/lib/tailscale/authkey";

    # Enable useful Tailscale features
    useRoutingFeatures = "server"; # For K3s nodes

    # Enable Tailscale SSH with port forwarding
    extraUpFlags = [
      "--ssh"
      "--ssh-allow-local-port-forwarding"
      "--ssh-allow-remote-port-forwarding"
      "--accept-dns=true"
      "--accept-routes=true"
    ];
  };

  # Configure networking for Tailscale
  networking = {
    # Firewall configuration
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
      checkReversePath = "loose";
    };

    # Enable MagicDNS
    nameservers = [ "100.100.100.100" ];
    search = [ "cinnamon-galaxy.ts.net" ]; # Your tailnet name
  };

  # Enable systemd-resolved for better DNS integration
  services.resolved = {
    enable = true;
    domains = [ "~cinnamon-galaxy.ts.net" ]; # Your tailnet name
  };

  # Install Tailscale packages
  environment.systemPackages = [
    pkgs.tailscale
    pkgs.tailscale-systray
    pkgs.tailscalesd
  ];
}
