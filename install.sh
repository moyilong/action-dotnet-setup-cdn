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
if [[ "${DOTNET_INSTALL_VERBOSE:-false}" == "true" ]]; then
  args_common+=(--verbose)
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

# dotnet requires ICU for normal globalization on Linux. Hosted runners usually
# provide it, but minimal self-hosted images often do not. Install the runtime
# package when a supported package manager is available.
install_icu_if_needed() {
  [[ "$(uname -s)" == "Linux" ]] || return 0

  if command -v ldconfig >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -qiE 'libicu[^ ]*\.so'; then
    return 0
  fi
  if find /usr/lib /lib -type f -name 'libicu*.so*' -print -quit 2>/dev/null | grep -q .; then
    return 0
  fi

  local runner=()
  if [[ "$(id -u)" -eq 0 ]]; then
    runner=()
  elif command -v sudo >/dev/null 2>&1; then
    runner=(sudo)
  else
    echo "No ICU library found and sudo is unavailable; install ICU (libicu/icu-libs) or set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true." >&2
    return 1
  fi

  if command -v apt-get >/dev/null 2>&1; then
    "${runner[@]}" apt-get update
    "${runner[@]}" apt-get install -y libicu-dev
  elif command -v dnf >/dev/null 2>&1; then
    "${runner[@]}" dnf install -y libicu
  elif command -v yum >/dev/null 2>&1; then
    "${runner[@]}" yum install -y libicu
  elif command -v apk >/dev/null 2>&1; then
    "${runner[@]}" apk add --no-cache icu-libs
  elif command -v zypper >/dev/null 2>&1; then
    "${runner[@]}" zypper --non-interactive install libicu
  else
    echo "No supported package manager found; install ICU (libicu/icu-libs) or set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true." >&2
    return 1
  fi
}

install_icu_if_needed
dotnet --info
