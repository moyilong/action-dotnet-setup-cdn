#!/usr/bin/env bash
set -euo pipefail

# Install one or more .NET SDK versions. A full SDK version (for example
# 11.0.100) is installed exactly; a major/minor version (11.0 or 11) is
# resolved by dotnet-install.sh to the latest SDK in that channel.

versions="${DOTNET_SDK_VERSION:-${DOTNET_SDK_VERSIONS:-}}"
if [[ -z "$versions" ]]; then
  echo "DOTNET_SDK_VERSION must contain at least one version" >&2
  exit 2
fi

install_dir="${DOTNET_INSTALL_DIR:-$HOME/.dotnet}"
installer="${DOTNET_INSTALLER:-}"
if [[ -z "$installer" ]]; then
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
fi

args_common=(--install-dir "$install_dir")
if [[ -n "${DOTNET_CDN:-}" ]]; then
  args_common+=(--azure-feed "${DOTNET_CDN%/}")
fi
if [[ "${SKIP_NON_VERSIONED_FILES:-true}" == "true" ]]; then
  args_common+=(--skip-non-versioned-files)
fi

versions="${versions//,/ }"
versions="${versions//;/ }"
for version in $versions; do
  [[ -z "$version" ]] && continue
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.].*)?$ ]]; then
    args=(--version "$version")
  elif [[ "$version" =~ ^[0-9]+\.[0-9]+$ || "$version" =~ ^[0-9]+$ ]]; then
    args=(--channel "$version" --quality GA)
  else
    echo "Invalid .NET SDK version: $version (expected X, X.Y, or X.Y.Z)" >&2
    exit 2
  fi
  echo "Installing .NET SDK $version"
  bash "$installer" "${args_common[@]}" "${args[@]}"
done

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "DOTNET_ROOT=$install_dir" >> "$GITHUB_ENV"
fi
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$install_dir" >> "$GITHUB_PATH"
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "dotnet-root=$install_dir" >> "$GITHUB_OUTPUT"
fi

export DOTNET_ROOT="$install_dir"
export PATH="$install_dir:$PATH"
dotnet --info
