#!/bin/bash
set -e

# MathFonts Simple Release Script
# This script creates a basic release with font archives

# Check for help or dry-run flags
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [VERSION] [--dry-run]"
    echo ""
    echo "Creates a MathFonts release with font archives"
    echo ""
    echo "Arguments:"
    echo "  VERSION     Version number (default: auto-increment from git tags)"
    echo "  --dry-run   Show what would be done without building fonts"
    echo ""
    echo "Examples:"
    echo "  $0              # Auto-increment version, build all fonts"
    echo "  $0 v1.2.3       # Use specific version"
    echo "  $0 --dry-run    # Test without building fonts"
    echo "  $0 v1.2.3 --dry-run  # Test specific version"
    exit 0
fi

# Parse arguments
DRY_RUN=false
VERSION=""

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$arg"
            fi
            ;;
    esac
done

# Set default version if not provided
if [[ -z "$VERSION" ]]; then
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [[ -n "$LATEST_TAG" ]]; then
        # Increment patch version
        VERSION=$(echo "$LATEST_TAG" | sed 's/v//' | awk -F. '{print $1"."$2"."$3+1}')
    else
        # No tags exist, start with 1.0.0
        VERSION="1.0.0"
    fi
fi
VERSION="v${VERSION#v}"  # Ensure v prefix

echo "Creating MathFonts release $VERSION"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "(DRY RUN MODE - no actual fonts will be built)"
fi

# Create tmp directory if it doesn't exist
mkdir -p tmp

if [[ "$DRY_RUN" == "true" ]]; then
    # Create dummy dist for dry run in a temporary location
    echo "Creating dummy font files for testing..."
    DIST_DIR="tmp/dist-dryrun"
    mkdir -p "$DIST_DIR/TestFont"
    echo "Test font file" > "$DIST_DIR/TestFont/TestFont.woff2"
    echo "Test license" > "$DIST_DIR/TestFont/LICENSE"
    echo "Would run: make clean && make all-parallel"
else
    # Build fonts
    echo "Building fonts (this may take several minutes)..."
    echo "You can interrupt with Ctrl+C if needed"
    DIST_DIR="dist"
    make clean
    make all-parallel
fi

# Check if dist exists
if [ ! -d "$DIST_DIR" ]; then
    echo "Error: $DIST_DIR directory not created"
    exit 1
fi

# Create version without v prefix for filenames
VERSION_CLEAN=${VERSION#v}

# Create ZIP archive
echo "Creating ZIP archive..."
if [[ "$DRY_RUN" == "true" ]]; then
    (cd "$DIST_DIR" && zip -r "../../tmp/mathfonts-$VERSION_CLEAN.zip" .)
else
    (cd "$DIST_DIR" && zip -r "../tmp/mathfonts-$VERSION_CLEAN.zip" .)
fi

# Create TAR.GZ archive
echo "Creating TAR.GZ archive..."
tar -czf "tmp/mathfonts-$VERSION_CLEAN.tar.gz" -C "$DIST_DIR" .

# Calculate sizes
ZIP_SIZE=$(du -h "tmp/mathfonts-$VERSION_CLEAN.zip" | cut -f1)
TAR_SIZE=$(du -h "tmp/mathfonts-$VERSION_CLEAN.tar.gz" | cut -f1)
FONT_COUNT=$(find "$DIST_DIR" -name "*.woff2" | wc -l)

echo "Release archives created:"
echo "  - mathfonts-$VERSION_CLEAN.zip ($ZIP_SIZE)"
echo "  - mathfonts-$VERSION_CLEAN.tar.gz ($TAR_SIZE)"
echo "  - Contains $FONT_COUNT WOFF2 font files"

if [[ "$DRY_RUN" == "false" ]]; then
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
    
    # Clean up dist directory to keep repo clean (only in real mode)
    echo "Cleaning up dist directory..."
    rm -rf dist
else
    echo ""
    echo "DRY RUN completed! No git tag created."
    echo "In a real run, this would:"
    echo "  1. Build all fonts with 'make all-parallel'"
    echo "  2. Create git tag $VERSION"
    echo "  3. Create release archives with real fonts"
    
    # Clean up only the temporary dry-run directory
    echo "Cleaning up temporary dry-run directory..."
    rm -rf "$DIST_DIR"
fi 