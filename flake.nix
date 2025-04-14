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
    # Define pkgs ONCE in the outer let block
    pkgs = import nixpkgs {
      inherit system;
      config = { allowUnfree = true; };
    };

    # --- Define Logical Hostnames (Matching Tailscale Names) ---
    controlPlaneName = "thinkpad-nixos"; # Tailscale name of the control plane
    workerNames = [ "hetzner-1" "auslander-nixos" ]; # Tailscale names of the workers

    # --- Define Control Plane Address (using Tailscale FQDN is recommended) ---
    # Replace 'cinnimon-galaxy' with your actual tailnet name.
    k3sControlPlaneAddr = "${controlPlaneName}.cinnimon-galaxy.ts.net"; # <<< VERIFY/SET YOUR TAILNET NAME

    # --- Helper Function to Create Control Plane Config ---
    # pkgs is inherited from the outer let block
    mkControlConfig = hostName: lib.nixosSystem {
      inherit system;
      # REMOVED 'pkgs' from specialArgs
      specialArgs = { inherit hostName lib disko; };
      modules = [
        ./modules/k3s-control.nix
        # Keep disko module import ONLY if k3s-control.nix uses disko.devices
        disko.nixosModules.disko
        # sops-nix...
      ];
    };

    # --- Helper Function to Create Worker Configs ---
    # pkgs is inherited from the outer let block
    mkWorkerConfig = hostName: lib.nixosSystem {
      inherit system;
      # REMOVED 'pkgs' and 'disko' from specialArgs
      specialArgs = {
        inherit hostName k3sControlPlaneAddr lib;
      };
      modules = [
        # The COMPLETE worker configuration module
        ./modules/k3s-worker.nix # Defines base settings internally now
        # No disko module import
        # No tailscale module import (handled within k3s-worker.nix)
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
      nodes =
        { "${controlPlaneName}" = { # Control Plane Target
             hostname = controlPlaneName; # Placeholder
             sshUser = "root"; # Placeholder
             fastConnection = true;
             profiles.system = { user = "root"; path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations."${controlPlaneName}"; };
           };
        } // (lib.genAttrs workerNames (name: { # Worker Targets
             hostname = name; # Placeholder
             sshUser = "root"; # Placeholder
             fastConnection = true;
             profiles.system = { user = "root"; path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations."${name}"; };
           }));
    };

    # Expose deploy-rs lib and checks
    packages.${system}.deploy-rs = deploy-rs.packages.${system}.deploy-rs;
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

  };
}