#!/usr/bin/env bash

set -euo pipefail

# Read the arguments input into an array, so it can be added to a command line.
IFS=" " read -r -a arguments <<<"${INPUT_ARGUMENTS:-}"

# Add all environment variables except for PATH to GITHUB_ENV.
while IFS='=' read -r -d '' n v; do
	if [ "$n" == "PATH" ]; then
		continue
	fi
	if (("$(wc -l <<<"$v")" > 1)); then
		delimiter=$(openssl rand -base64 12)
		printf "%s<<%s\n%s%s\n" "$n" "$delimiter" "$v" "$delimiter" >>"${GITHUB_ENV:-/dev/stderr}"
		continue
	fi
	printf "%s=%s\n" "$n" "$v" >>"${GITHUB_ENV:-/dev/stderr}"
done < <(nix develop --ignore-environment "${arguments[@]}" --command env -0)

# Read the nix environment's $PATH into an array
IFS=":" read -r -a nix_path_array <<<"$(nix develop "${arguments[@]}" --command bash -c "echo \$PATH")"

# Iterate over the PATH array in reverse
#
# Why in reverse?  Appending a directory to $GITHUB_PATH causes that directory
# to be _prepended_ to $PATH in subsequent steps, so if we append in
# first-to-last order, the result will be in last-to-first order.  Order in
# PATH elements is significant, since it determines lookup order, thus we
# preserve their order by reversing them before they are reversed again.
for ((i = ${#nix_path_array[@]} - 1; i >= 0; i--)); do
	nix_path_entry="${nix_path_array[$i]}"
	# Don't add anything that's already present in the $PATH
	if echo "$PATH" | grep "$nix_path_entry" --silent; then
		continue
	fi
	echo "$nix_path_entry" >>"${GITHUB_PATH:-/dev/stderr}"
done
