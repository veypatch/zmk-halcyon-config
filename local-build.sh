#!/usr/bin/env bash
set -euo pipefail

# Hard-coded local paths
ZMK_CONFIG="/workspaces/zmk-config/config"
ZMK_EXTRA_MODULES="/workspaces/zmk-modules;/workspaces/zmk-modules2;/workspaces/zmk-modules3"

BUILD_ROOT="build"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-build.yaml>"
    exit 1
fi

BUILD_YAML="$1"

if [[ ! -f "$BUILD_YAML" ]]; then
    echo "Error: build.yaml not found: $BUILD_YAML"
    exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
    echo "Error: yq is required"
    exit 1
fi

entries=$(yq '.include | length' "$BUILD_YAML")

for ((i=0; i<entries; i++)); do
    board=$(yq -r ".include[$i].board" "$BUILD_YAML")
    shield=$(yq -r ".include[$i].shield // \"\"" "$BUILD_YAML")
    artifact=$(yq -r ".include[$i].\"artifact-name\" // \"\"" "$BUILD_YAML")

    if [[ -z "$artifact" || "$artifact" == "null" ]]; then
        artifact="${shield:+${shield// /-}-}${board//\//_}-zmk"
    fi
    snippet=$(yq -r ".include[$i].snippet // \"\"" "$BUILD_YAML")
    cmake_arg=$(yq -r ".include[$i].\"cmake-args\" // \"\"" "$BUILD_YAML")

    echo
    echo "======================================"
    echo "Building: $artifact"
    echo "Board:    $board"
    echo "Shield:   $shield"
    echo "Snippet:  $snippet"
    echo "======================================"

    west_args=()

    if [[ -n "$snippet" ]]; then
        west_args+=("-S" "$snippet")
    fi

    cmake_args=(
        "-DZMK_CONFIG=$ZMK_CONFIG"
        "-DZMK_EXTRA_MODULES=$ZMK_EXTRA_MODULES"
    )

    if [[ -n "$shield" ]]; then
        cmake_args+=("-DSHIELD=$shield")
    fi

    if [[ -n "$cmake_arg" && "$cmake_arg" != "null" ]]; then
        cmake_args+=("$cmake_arg")
    fi

    west build \
        -d "$BUILD_ROOT/$artifact" \
        -p \
        -s /workspaces/zmk/app \
        "${west_args[@]}" \
        -b "$board" \
        -- \
        "${cmake_args[@]}"

    mkdir -p "$BUILD_ROOT/artifacts"

    if [[ -f "$BUILD_ROOT/$artifact/zephyr/zmk.uf2" ]]; then
        cp \
            "$BUILD_ROOT/$artifact/zephyr/zmk.uf2" \
            "$BUILD_ROOT/artifacts/$artifact.uf2"

        echo "Created: $BUILD_ROOT/artifacts/$artifact.uf2"

    elif [[ -f "$BUILD_ROOT/$artifact/zephyr/zmk.bin" ]]; then
        cp \
            "$BUILD_ROOT/$artifact/zephyr/zmk.bin" \
            "$BUILD_ROOT/artifacts/$artifact.bin"

        echo "Created: $BUILD_ROOT/artifacts/$artifact.bin"

    else
        echo "WARNING: no firmware output found for $artifact"
    fi
done

echo
echo "All builds completed."
