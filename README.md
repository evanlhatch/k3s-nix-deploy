# K3s NixOS Flake with Infisical Secret Management

This repository contains a NixOS flake for deploying a K3s Kubernetes cluster with Tailscale networking. It uses deploy-rs for deployment and Infisical for secret management.

## Prerequisites

- NixOS or Nix with flakes enabled
- [just](https://github.com/casey/just) command runner (`nix-shell -p just` or add to your system packages)
- [Infisical CLI](https://infisical.com/docs/cli/overview) installed and configured (`infisical login`)
- SSH access to your target machines

## Setup

1. **Configure your Infisical secrets**

   Ensure you have the following secrets set up in your Infisical project "nixos-anywhere":
   - `tailscale`: Your Tailscale auth key
   - `K3S_TOKEN`: A token for K3s node authentication (will be generated if it doesn't exist)

2. **Update the Justfile configuration**

   - Edit the IP addresses and SSH users for your nodes in the Justfile
   - For example, update `ip_worker1` and `user_worker1` with your actual values

3. **Update the flake.nix configuration**

   - Edit the `controlPlaneHost` variable to match your control plane's hostname

4. **Generate K3s token (if needed)**

   If you don't already have a K3s token in Infisical:
   ```
   just generate_k3s_token
   ```

5. **Build and deploy your cluster**

   To build the worker node configuration locally (without deploying):
   ```
   just build worker1
   ```

   To deploy the control plane node:
   ```
   just deploy control1
   ```

   To deploy a worker node:
   ```
   just deploy worker1
   ```

## How It Works

The Justfile automates the following process:

1. Fetches secrets from Infisical and stores them in the `./secrets` directory
2. The flake.nix reads these secrets during the build process
3. deploy-rs deploys the configuration to the specified nodes

## Available Commands

- `just`: List all available commands
- `just generate_k3s_token`: Generate a K3s token and upload it to Infisical (only if it doesn't already exist)
- `just secrets`: Fetch secrets from Infisical without deploying
- `just build <node_name>`: Build the configuration for a node locally without deploying
- `just deploy <node_name>`: Deploy to a specific node (e.g., `control1` or `worker1`)
- `just clean`: Remove the fetched secrets

## Security Notes

- The `secrets` directory is added to `.gitignore` to prevent accidental commits
- Secrets are only stored locally during the deployment process
- Run `just clean` after deployment to remove local secret files

## Customization

- Edit the flake.nix to customize your K3s configuration
- Modify the Justfile if you need to fetch additional secrets
- Add more nodes to the `deploy.nodes` section as needed
