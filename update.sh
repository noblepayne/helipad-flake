#!/usr/bin/env bash
set -euo pipefail

echo "Updating helipad..."
nix-update helipad --flake --commit

echo "All done!"
