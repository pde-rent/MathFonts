#!/bin/bash
set -e

# MathFonts Simple Release Script
# This script creates a basic release with font archives

VERSION=${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/v//' | awk -F. '{print $1"."$2"."$3+1}' || echo "1.0.0")}
VERSION="v${VERSION#v}"  # Ensure v prefix

echo "Creating MathFonts release $VERSION"

# Create tmp directory if it doesn't exist
mkdir -p tmp

# Build fonts
echo "Building fonts..."
make clean
make all-parallel

# Check if dist exists
if [ ! -d "dist" ]; then
    echo "Error: dist directory not created"
    exit 1
fi

# Create version without v prefix for filenames
VERSION_CLEAN=${VERSION#v}

# Create ZIP archive
echo "Creating ZIP archive..."
cd dist
zip -r "../tmp/mathfonts-$VERSION_CLEAN.zip" .
cd ..

# Create TAR.GZ archive
echo "Creating TAR.GZ archive..."
tar -czf "tmp/mathfonts-$VERSION_CLEAN.tar.gz" -C dist .

# Calculate sizes
ZIP_SIZE=$(du -h "tmp/mathfonts-$VERSION_CLEAN.zip" | cut -f1)
TAR_SIZE=$(du -h "tmp/mathfonts-$VERSION_CLEAN.tar.gz" | cut -f1)
FONT_COUNT=$(find dist -name "*.woff2" | wc -l)

echo "Release archives created:"
echo "  - mathfonts-$VERSION_CLEAN.zip ($ZIP_SIZE)"
echo "  - mathfonts-$VERSION_CLEAN.tar.gz ($TAR_SIZE)"
echo "  - Contains $FONT_COUNT WOFF2 font files"

# Create git tag
echo "Creating git tag $VERSION..."
git tag -a "$VERSION" -m "Release $VERSION"

echo ""
echo "Release $VERSION ready!"
echo "To complete the release:"
echo "  1. Push the tag: git push origin $VERSION"
echo "  2. Create GitHub release manually and attach:"
echo "     - tmp/mathfonts-$VERSION_CLEAN.zip"
echo "     - tmp/mathfonts-$VERSION_CLEAN.tar.gz"
echo "  3. Or use: python release.py --version $VERSION --token YOUR_GITHUB_TOKEN"

# Clean up dist directory to keep repo clean
echo "Cleaning up dist directory..."
rm -rf dist 