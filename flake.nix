# ./flake.nix
{
  description = "NixOS configurations for Minimal K3s Control Plane and Workers using Tailscale Names";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # sops-nix.url = "github:Mic92/sops-nix"; # For later
    # sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, deploy-rs, disko, /* sops-nix, */ ... }:
  let
    system = "x86_64-linux"; # Or "aarch64-linux"
    lib = nixpkgs.lib;
    pkgs = import nixpkgs { # Make pkgs accessible if needed
      inherit system;
      config = { allowUnfree = true; };
    };

    # --- Define Logical Hostnames (Matching Tailscale Names) ---
    # These names MUST match the keys used in the Justfile deploy/build commands AND Tailscale hostnames
    controlPlaneName = "thinkpad-nixos"; # Tailscale name of the control plane
    workerNames = [ "hetzner-1" "auslander-nixos" ]; # Tailscale names of the workers

    # --- Define Control Plane Address (using Tailscale FQDN is recommended) ---
    # This is how workers find the K3s API server. Replace 'YOUR-TAILNET' below.
    k3sControlPlaneAddr = "${controlPlaneName}.cinnimon-galaxy.ts.net"; # <<< IMPORTANT: SET YOUR TAILNET NAME

    # --- Helper Function to Create Control Plane Config ---
    mkControlConfig = hostName: lib.nixosSystem {
      inherit system;
      specialArgs = { inherit hostName pkgs lib disko; };
      modules = [
        ./modules/k3s-control.nix
        disko.nixosModules.disko
        ./modules/tailscale.nix
        # sops-nix.nixosModules.sops # For later
      ];
    };

    # --- Helper Function to Create Worker Configs ---
    mkWorkerConfig = hostName: lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit hostName k3sControlPlaneAddr pkgs lib disko;
      };
      modules = [
        # The COMPLETE worker configuration module
        ./modules/k3s-worker.nix # Defines base settings internally now

        # --- Add this line back if missing ---
        # Include Tailscale module (k3s-worker.nix enables it)
        ./modules/tailscale.nix
        # ------------------------------------

        # Include Disko module (k3s-worker.nix defines the layout)
        disko.nixosModules.disko

        # sops-nix integration later...
      ];
    };

    # --- Generate Configurations ---
    controlPlaneConfiguration = mkControlConfig controlPlaneName;
    workerConfigurations = lib.genAttrs workerNames mkWorkerConfig;

  in {
    # NixOS Configurations per Host (keyed by Tailscale name)
    nixosConfigurations =
      { "${controlPlaneName}" = controlPlaneConfiguration; } // workerConfigurations;

    # Deploy-rs Configuration
    deploy = {
      autoRollback = true;
      # Nodes keyed by Tailscale name
      nodes =
        # --- Control Plane Target ---
        { "${controlPlaneName}" = {
             # Hostname here is now just a logical placeholder, Tailscale name resolution is key
             hostname = controlPlaneName;
             # SSH User is still needed for the connection override from Justfile
             sshUser = "root"; # Placeholder
             fastConnection = true; # Assume Tailscale connection is fast
             profiles.system = {
               user = "root"; # User for nixos-rebuild switch
               path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations."${controlPlaneName}";
             };
           };
        } //
        # --- Worker Targets (Generated) ---
        (lib.genAttrs workerNames (name: {
           hostname = name; # Placeholder
           sshUser = "root"; # Placeholder
           fastConnection = true;
           profiles.system = {
             user = "root";
             path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations."${name}";
           };
         }));
    };

    # Expose deploy-rs lib and checks
    packages.${system}.deploy-rs = deploy-rs.packages.${system}.deploy-rs;
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

  };
}
