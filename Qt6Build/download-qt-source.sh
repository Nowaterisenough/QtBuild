#!/bin/bash
# ============================================================================
# Download Qt Source
# Parameters: QT_VERSION
# ============================================================================

set -e

QT_VERSION="${1}"

if [ -z "$QT_VERSION" ]; then
    echo "ERROR: QT_VERSION not provided"
    exit 1
fi

echo "=== Downloading Qt ${QT_VERSION} Source ==="

# Extract major.minor version
major_minor=$(echo "$QT_VERSION" | cut -d. -f1-2)
source_url="https://download.qt.io/official_releases/qt/${major_minor}/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz"

echo "Downloading from: $source_url"
wget -q --show-progress -O "qt-everywhere-src-${QT_VERSION}.tar.xz" "$source_url"

echo "Qt source download completed"
