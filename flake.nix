# ./flake.nix
{
  description = "NixOS configurations using INSECURE secret inclusion in source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # sops-nix.url = "github:Mic92/sops-nix"; # For later
    # sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Use '@ inputs' to capture all inputs for lib.cleanSourceWith filter
  outputs = { self, nixpkgs, deploy-rs, disko, ... }@inputs:
  let
    lib = nixpkgs.lib; # Get lib for cleanSourceWith filter

    # --- Define self' with overridden source ---
    # WARNING: This includes the './secrets' directory in the flake source,
    # copying plain-text secrets into the Nix store on the target machine.
    self' = self.overrideAttrs (old: {
      src = lib.cleanSourceWith {
         # Use the current directory as the source root
         src = ./.;
         # Include Git-tracked files AND the 'secrets' directory + its contents
         filter = path: type:
           let baseName = baseNameOf path;
           in (lib.cleanSourceFilter path type) || (baseName == "secrets");
       };
    });
    # -------------------------------------------

    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = { allowUnfree = true; };
    };

    # --- Define Logical Hostnames ---
    controlPlaneName = "thinkpad-nixos"; # Tailscale name of the control plane
    workerNames = [ "hetzner-1" "auslander-nixos" ]; # Tailscale names of the workers

    # --- Define Control Plane Address ---
    # Replace 'cinnamon-galaxy' with your actual tailnet name.
    k3sControlPlaneAddr = "${controlPlaneName}.cinnamon-galaxy.ts.net"; # <<< VERIFY/SET YOUR TAILNET NAME

    # --- Helper Lists of Modules ---
    # Define lists of modules for each node type
    controlModules = [
      ./modules/k3s-control.nix
      # Keep disko module import ONLY if k3s-control.nix uses disko.devices
      disko.nixosModules.disko
      # No ./modules/tailscale.nix needed if k3s-control configures it directly
      # No ./modules/base.nix needed if k3s-control defines base settings
    ];
    workerModules = [
      ./modules/k3s-worker.nix # Configures base, k3s, tailscale directly
      # No disko module import needed if workers don't define layouts
      # No tailscale module import needed here
      # No base module import needed here
    ];

    # --- Generate NixOS Configurations USING self' context ---
    # This evaluates the modules within the context of the overridden source,
    # allowing paths like ../secrets/k3s.token to resolve correctly.
    generatedNixOSConfigs = {
      "${controlPlaneName}" = lib.nixosSystem {
        inherit system;
        # Pass specialArgs needed by the modules in controlModules
        specialArgs = { hostName = controlPlaneName; inherit pkgs lib disko; }; # Pass disko IF k3s-control uses it
        modules = controlModules; # Evaluated relative to self'.src
      };
    } // (lib.genAttrs workerNames (hostName:
        lib.nixosSystem {
          inherit system;
          # Pass specialArgs needed by the modules in workerModules
          specialArgs = { inherit hostName k3sControlPlaneAddr pkgs lib; }; # No disko needed
          modules = workerModules; # Evaluated relative to self'.src
        }
    ));

  in { # Start of main returned attrset

    # --- Expose the generated configurations ---
    # This is what deploy-rs or nixos-rebuild will build.
    nixosConfigurations = generatedNixOSConfigs;

    # --- Deploy-rs Configuration ---
    # The `path` here references the final configurations generated above.
    # It implicitly uses the derivations built using the self' context.
    deploy = {
      autoRollback = true;
      nodes =
        { "${controlPlaneName}" = { # Control Plane Target
             hostname = controlPlaneName; # Placeholder for connection override
             sshUser = "root"; # Placeholder for connection override
             fastConnection = true;
             profiles.system = { user = "root"; path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations."${controlPlaneName}"; };
           };
        } // (lib.genAttrs workerNames (name: { # Worker Targets
             hostname = name; # Placeholder for connection override
             sshUser = "root"; # Placeholder for connection override
             fastConnection = true;
             profiles.system = { user = "root"; path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations."${name}"; };
           }));
    };

    # --- Expose deploy-rs lib and checks ---
    packages.${system}.deploy-rs = deploy-rs.packages.${system}.deploy-rs;
    # Checks might fail if they don't use self' context correctly, may need adjustment if used
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

  }; # End of main returned attrset
}