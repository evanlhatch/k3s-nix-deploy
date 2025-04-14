#!/usr/bin/env just -f

# --- Configuration ---

# == Deployment Targets ==
# Define the IP addresses and SSH user for each logical node name.
# These logical names (thinkpad-nixos, hetzner-1, etc.) MUST match the keys defined in flake.nix.

# --- Control Plane ---
ts_name_thinkpad_nixos := "thinkpad-nixos" # Tailscale name (for reference)
ip_thinkpad_nixos := "PLACEHOLDER_IP"      # <<< SET IP ADDRESS
user_thinkpad_nixos  := "root"             # <<< SET SSH USER

# --- Worker Node(s) ---
ts_name_hetzner_1    := "hetzner-1"        # Tailscale name (for reference)
ip_hetzner_1 := "5.161.197.57"             # <<< SET IP ADDRESS
user_hetzner_1     := "root"               # <<< SET SSH USER

ts_name_auslander_nixos := "auslander-nixos" # Tailscale name (for reference)
ip_auslander_nixos := "PLACEHOLDER_IP"      # <<< SET IP ADDRESS
user_auslander_nixos  := "root"             # <<< SET SSH USER

# Add more workers here following the pattern ts_name_<flake_key> and user_<flake_key>

# == Nix Build Options ==
nix_build_args := "--show-trace"

# == Local Secrets Path ==
# NOTE: Assumes these files exist BEFORE running build/deploy
local_secrets_dir         := "./secrets"
local_tailscale_key_file := local_secrets_dir + "/tailscale.key"
local_k3s_token_file     := local_secrets_dir + "/k3s.token"


# --- User-Facing Commands ---

default:
	@just --list

# Build command uses the node name (Tailscale name)
# Assumes secrets files in ./secrets already exist locally
build node_name:
	# Validate node_name is one of the expected nodes
	@case "{{node_name}}" in \
		thinkpad-nixos|hetzner-1|auslander-nixos) \
			echo "==> Building NixOS configuration for node '{{node_name}}' locally..." \
			# Check if required secret files exist locally before building \
			if [[ ! -f "{{local_k3s_token_file}}" ]] || [[ ! -f "{{local_tailscale_key_file}}" ]]; then \
				echo "Error: Secret file(s) not found in {{local_secrets_dir}}." >&2 \
				echo "Please create {{local_k3s_token_file}} and {{local_tailscale_key_file}} manually." >&2 \
				exit 1 \
			fi \
			nix build .#nixosConfigurations.{{node_name}}.config.system.build.toplevel {{nix_build_args}} \
			;; \
		*) \
			echo "Error: Invalid node name '{{node_name}}' for build." >&2 \
			exit 1 \
			;; \
	esac
	@echo "==> Build check for '{{node_name}}' finished."

# Deploy command uses the node name (Tailscale name)
# Assumes secrets files in ./secrets already exist locally
deploy node_name:
	#!/usr/bin/env bash
	set -e

	# --- Define bash variables ---
	target_ip="" # IP Address for connection override
	target_user=""
	flake_node_name="{{node_name}}" # Logical name matching flake keys

	# --- Check if secrets files exist locally first ---
	local_k3s_token_file="./secrets/k3s.token"
	local_tailscale_key_file="./secrets/tailscale.key"
	if [[ ! -f "$local_k3s_token_file" ]] || [[ ! -f "$local_tailscale_key_file" ]]; then
		echo "Error: Secret file(s) not found in ./secrets." >&2
		echo "Please create $local_k3s_token_file and $local_tailscale_key_file manually." >&2
		exit 1
	fi
	echo "==> Found local secret files."

	# --- Determine IP and User based on node_name argument ---
	if [[ "$flake_node_name" == "thinkpad-nixos" ]]; then
		target_ip="{{ip_thinkpad_nixos}}"
		target_user="{{user_thinkpad_nixos}}"
	elif [[ "$flake_node_name" == "hetzner-1" ]]; then
		target_ip="{{ip_hetzner_1}}"
		target_user="{{user_hetzner_1}}"
	elif [[ "$flake_node_name" == "auslander-nixos" ]]; then
		target_ip="{{ip_auslander_nixos}}"
		target_user="{{user_auslander_nixos}}"
	# Add elif blocks here for other worker nodes if defined above
	else
		echo "Error: Unknown node name '$flake_node_name'" >&2
		echo "Please define ip_$flake_node_name and user_$flake_node_name in the Justfile configuration section." >&2
		exit 1
	fi

	# --- Validate that IP and User were found ---
	if [[ -z "$target_ip" ]] || [[ -z "$target_user" ]]; then
		echo "Error: IP address or User is not defined (or empty) for node '$flake_node_name' in Justfile." >&2
		exit 1
	fi

	# --- Construct URI for logging purposes ---
	target_uri="ssh://${target_user}@${target_ip}"
	echo "==> Deploying NixOS config for node '$flake_node_name' to '${target_uri}' using deploy-rs..."

	# --- Construct the command array dynamically for deploy-rs ---
	cmd=(deploy) # Use deploy-rs directly

	# Add override flags
	cmd+=(--hostname "$target_ip" --ssh-user "$target_user")

	# Add the target flake profile positionally
	cmd+=(".#{{node_name}}") # e.g. .#hetzner-1

	# Get the value of nix_build_args into a bash variable
	nix_build_args_val="{{nix_build_args}}"

	# Conditionally add the '--' separator AND the build args
	if [[ -n "$nix_build_args_val" ]]; then
	  cmd+=(--) # Add the separator for Nix build arguments
	  cmd+=($nix_build_args_val) # Use word splitting intentionally
	fi

	# --- Execute the constructed command ---
	echo "Executing: ${cmd[@]}"
	"${cmd[@]}"

	echo "==> Deployment process for '$flake_node_name' finished."

# Clean recipe could optionally remove the manually created secrets
# clean:
#	@echo "==> Removing local secrets directory (if desired)..."
#	# rm -rf {{local_secrets_dir}}
#	# @echo "    Removed {{local_secrets_dir}}"
