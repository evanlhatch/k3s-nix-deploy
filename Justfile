#!/usr/bin/env just -f

# --- Configuration ---

# == Deployment Targets ==
# Define the IP addresses and SSH user for each logical node name.
# These logical names (thinkpad-nixos, hetzner-1, etc.) MUST match the keys defined in flake.nix.

# --- Control Plane ---
ts_name_thinkpad_nixos := "thinkpad-nixos" # Tailscale name (for reference)
ip_thinkpad_nixos := "PLACEHOLDER_IP"      # <<< SET IP ADDRESS
user_thinkpad_nixos  := "root"             # <<< SET SSH USER (often 'root' or your Tailscale user if --ssh is enabled)

# --- Worker Node(s) ---
ts_name_hetzner_1    := "hetzner-1"        # Tailscale name (for reference)
ip_hetzner_1 := "5.161.197.57"             # <<< SET IP ADDRESS
user_hetzner_1     := "root"               # <<< SET SSH USER

ts_name_auslander_nixos := "auslander-nixos" # Tailscale name (for reference)
ip_auslander_nixos := "PLACEHOLDER_IP"      # <<< SET IP ADDRESS
user_auslander_nixos  := "root"             # <<< SET SSH USER

# Add more workers here following the pattern ts_name_<flake_key> and user_<flake_key>

# == Infisical Secrets ==
infisical_tailscale_secret_name := "tailscale"
infisical_k3s_secret_name := "K3S_TOKEN"

# == Local Secrets Path ==
local_secrets_dir         := "./secrets"
local_tailscale_key_file := local_secrets_dir + "/tailscale.key"
local_k3s_token_file     := local_secrets_dir + "/k3s.token"

# == Nix Build Options ==
nix_build_args := "--show-trace"


# --- Internal Tasks ---
_ensure_secrets_dir:
    mkdir -p {{local_secrets_dir}}

_fetch_tailscale_key: _ensure_secrets_dir
    @echo "==> Fetching Tailscale Auth Key from Infisical..."
    infisical secrets get {{infisical_tailscale_secret_name}} --plain > {{local_tailscale_key_file}}
    @echo "    Saved to {{local_tailscale_key_file}}"

_fetch_k3s_token: _ensure_secrets_dir
    @echo "==> Fetching K3s Token from Infisical..."
    infisical secrets get {{infisical_k3s_secret_name}} --plain > {{local_k3s_token_file}} 2>/dev/null || echo "K3s token not found, you may need to generate one"
    @echo "    Saved to {{local_k3s_token_file}}"


# --- User-Facing Commands ---

default:
    @just --list

# Check if K3s token exists in Infisical, generate only if it doesn't exist
generate_k3s_token: _ensure_secrets_dir
    @echo "==> Checking if K3s token already exists in Infisical..."
    if ! infisical secrets get {{infisical_k3s_secret_name}} --plain > /dev/null 2>&1; then \
        echo "==> K3s token not found. Generating new token..."; \
        openssl rand -hex 16 > {{local_k3s_token_file}}; \
        echo "    Token generated and saved to {{local_k3s_token_file}}"; \
        echo "==> Uploading K3s token to Infisical..."; \
        cat {{local_k3s_token_file}} | infisical secrets set {{infisical_k3s_secret_name}} --value-from-stdin; \
        echo "    Token uploaded to Infisical"; \
    else \
        echo "==> K3s token already exists in Infisical. No need to generate a new one."; \
        infisical secrets get {{infisical_k3s_secret_name}} --plain > {{local_k3s_token_file}}; \
        echo "    Existing token saved to {{local_k3s_token_file}}"; \
    fi

secrets: _fetch_tailscale_key _fetch_k3s_token
    @echo "==> Secrets fetched successfully."

# Build command uses the node name (Tailscale name)
build node_name: _fetch_tailscale_key _fetch_k3s_token
    # Validate node_name is one of the expected nodes
    @case "{{node_name}}" in \
        thinkpad-nixos|hetzner-1|auslander-nixos) \
            echo "==> Building NixOS configuration for node '{{node_name}}' locally..."; \
            nix build .#nixosConfigurations.{{node_name}}.config.system.build.toplevel {{nix_build_args}};; \
        *) \
            echo "Error: Invalid node name '{{node_name}}' for build." >&2; \
            exit 1;; \
    esac
    @echo "==> Build check for '{{node_name}}' finished."

# Deploy command uses the node name (Tailscale name)
deploy node_name: _fetch_tailscale_key _fetch_k3s_token
    #!/usr/bin/env bash
    set -e

    # --- Define bash variables ---
    target_host="" # Changed from target_ip to target_host
    target_user=""

    # --- Determine IP and User based on node_name argument ---
    if [[ "{{node_name}}" == "thinkpad-nixos" ]]; then
        target_host="{{ip_thinkpad_nixos}}"
        target_user="{{user_thinkpad_nixos}}"
    elif [[ "{{node_name}}" == "hetzner-1" ]]; then
        target_host="{{ip_hetzner_1}}"
        target_user="{{user_hetzner_1}}"
    elif [[ "{{node_name}}" == "auslander-nixos" ]]; then
        target_host="{{ip_auslander_nixos}}"
        target_user="{{user_auslander_nixos}}"
    # Add elif blocks here for other worker nodes if defined above
    else
        echo "Error: Unknown node name '{{node_name}}'" >&2
        echo "Please define ts_name_{{node_name}} and user_{{node_name}} in the Justfile configuration section." >&2
        exit 1
    fi

    # --- Validate that IP and User were found ---
    if [[ -z "$target_host" ]] || [[ -z "$target_user" ]]; then
        echo "Error: IP address or User is not defined (or empty) for node '{{node_name}}' in Justfile." >&2
        exit 1
    fi

    # --- Define the Flake Profile Target ---
    flake_profile_target=".#{{node_name}}" # e.g., .#thinkpad-nixos or .#hetzner-1

    # --- Construct URI for logging purposes ---
    target_uri="ssh://${target_user}@${target_host}" # Uses IP address now
    echo "==> Deploying NixOS profile '${flake_profile_target}' to '${target_uri}' (using IP address)..."

    # --- Deploy using nixos-rebuild ---
    echo "Deploying using nixos-rebuild..."
    nixos-rebuild switch --flake ".#{{node_name}}" --target-host "${target_user}@${target_host}" --use-remote-sudo

    echo "==> Deployment process for '{{node_name}}' finished."

clean:
    @echo "==> Removing fetched secrets directory..."
    rm -rf {{local_secrets_dir}}
    @echo "    Removed {{local_secrets_dir}}"
