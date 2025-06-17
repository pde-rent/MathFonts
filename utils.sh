#!/bin/bash
# Font Build Utilities - Fully Generic with Auto-Detection
set -euo pipefail

# Colors and logging
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

# Global variables
PYTHON_CMD="${PYTHON_CMD:-python3}"
PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
TMP_DIR="${TMP_DIR:-$PROJECT_ROOT/tmp}"
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"

# Core utilities
download() {
    local url="$1" output="${2:-}"
    if command -v curl >/dev/null 2>&1; then
        # Silent, follow redirects, fail on HTTP errors, parallel-friendly
        if [[ -n "$output" ]]; then
            # Ensure output directory exists
            mkdir -p "$(dirname "$output")" 2>/dev/null || true
            curl -sSLf "$url" -o "$output"
        else
            curl -sSLf "$url" -O
        fi
    else
        if [[ -n "$output" ]]; then
            mkdir -p "$(dirname "$output")" 2>/dev/null || true
            wget -q "$url" -O "$output"
        else
            wget -q "$url"
        fi
    fi
}

auto_extract() {
    local archive="$1"
    case "$(echo "$archive" | tr '[:upper:]' '[:lower:]')" in
        *.zip) unzip -o "$archive" ;;
        *.tar.gz|*.tgz) tar -xzf "$archive" ;;
        *.tar.bz2) tar -xjf "$archive" ;;
        *.tar) tar -xf "$archive" ;;
        *.7z) 7z x "$archive" ;;
        *.rar) unrar x "$archive" ;;
        *) warn "Unknown archive format: $archive" ;;
    esac
}

download_and_extract_all() {
    local name="$1"; shift
    local urls=("$@")

    if [ ${#urls[@]} -eq 0 ]; then
        warn "[$name] No URLs provided, skipping download."
        return
    fi
    local tmp_dir="$PROJECT_ROOT/$TMP_DIR/$name"
    local original_dir="$PWD"
    
    cd "$tmp_dir"
    
    # Always use parallel downloads within each font - Make handles font-level parallelism
    local pids=()
    local files=()
    log "[$name] Starting download of ${#urls[@]} files..."
    
    for url in "${urls[@]}"; do
        local filename=$(basename "$url" | sed 's/[?#].*$//')
        files+=("$filename")
        download "$url" "$filename" &
        pids+=($!)
    done
    
    # Wait for all downloads to complete
    wait "${pids[@]}"
    log "[$name] All downloads completed."
    
    # Extract archives sequentially (fast operation)
    for filename in "${files[@]}"; do
        if [[ "$filename" =~ \.(zip|tar\.gz|tgz|tar\.bz2|tar|7z|rar)$ ]]; then
            auto_extract "$filename" >/dev/null 2>&1
            rm -f "$filename" # cleanup archive after extraction
        fi
    done
    
    cd "$original_dir"
}

# New two-phase build functions
download_and_setup() {
    local name="$1"; shift
    local urls=("$@")
    log "Preparing to download $name..."
    mkdir -p "$PROJECT_ROOT/$TMP_DIR/$name" "$PROJECT_ROOT/$DIST_DIR/$name"
    download_and_extract_all "$name" "$@"
}

process_and_finalize() {
    local name="$1"
    log "Processing font: $name"
    copy_all_fonts "$name"
    copy_and_standardize_licenses "$name"
    finalize_font "$name"
    success "Successfully built $name"
}

process_and_finalize_simple() {
    local name="$1" dates="${2:-}" holder="${3:-}" font_name="${4:-}"
    process_and_finalize "$name"
    if [[ -n "$dates" || -n "$holder" || -n "$font_name" ]]; then
        log "Running OFL setup for $name"
        setup_ofl "$PROJECT_ROOT/$DIST_DIR/$name" "$dates" "$holder" "$font_name"
    fi
}

copy_all_fonts() {
    local name="$1"
    local tmp_dir="$PROJECT_ROOT/$TMP_DIR/$name"
    local dist_dir="$PROJECT_ROOT/$DIST_DIR/$name"
    
    # Ensure dist directory exists
    mkdir -p "$dist_dir"
    
    # Find and copy all font files recursively
    if [[ -d "$tmp_dir" ]]; then
        local font_count=0
        while IFS= read -r -d '' font_file; do
            cp "$font_file" "$dist_dir/" || warn "[$name] Failed to copy $font_file"
            ((font_count++))
        done < <(find "$tmp_dir" \( -name "*.otf" -o -name "*.ttf" -o -name "*.woff" -o -name "*.woff2" \) -print0 2>/dev/null)
        
        if [[ $font_count -gt 0 ]]; then
            log "[$name] Copied $font_count font files"
        else
            warn "[$name] No font files found in $tmp_dir"
        fi
    else
        warn "[$name] Temp directory $tmp_dir does not exist"
    fi
}

copy_and_standardize_licenses() {
    local name="$1"
    local tmp_dir="$PROJECT_ROOT/$TMP_DIR/$name"
    local dist_dir="$PROJECT_ROOT/$DIST_DIR/$name"
    
    if [[ -d "$tmp_dir" ]]; then
        # Find the primary license file and standardize it immediately
        local license_found=false
        
        # Priority order: LICENSE > COPYING > OFL > GUST-FONT-LICENSE
        for pattern in "LICENSE*" "COPYING*" "OFL.*" "GUST-FONT-LICENSE*"; do
            local license_file=$(find "$tmp_dir" -maxdepth 3 -iname "$pattern" -type f | head -1)
            if [[ -n "$license_file" && ! "$license_found" == "true" ]]; then
                cp "$license_file" "$dist_dir/LICENSE" 2>/dev/null && license_found=true
                success "Standardized $(basename "$license_file") → LICENSE"
                break
            fi
        done
        
        # Copy other documentation files (README, MANIFEST, etc.)
        find "$tmp_dir" -maxdepth 3 \( -iname "*readme*" -o -iname "*manifest*" -o -iname "*fontlog*" \) -type f -exec cp {} "$dist_dir/" \; 2>/dev/null || true
        
        # Remove unwanted files from dist
        find "$dist_dir" -maxdepth 1 -name "._*" -o -name "*FAQ*" -type f -delete 2>/dev/null || true
    fi
}

compress_fonts() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        warn "Directory $dir does not exist, skipping compression"
        return 1
    fi
    
    local original_dir="$PWD"
    cd "$dir" || {
        warn "Failed to change to directory $dir"
        return 1
    }
    
    # Use find instead of ls to avoid zsh globbing issues
    local fonts=()
    while IFS= read -r -d '' font_file; do
        fonts+=("$(basename "$font_file")")
    done < <(find . -maxdepth 1 \( -name "*.otf" -o -name "*.ttf" \) -print0 2>/dev/null)
    
    if [[ ${#fonts[@]} -gt 0 ]]; then
        "$PYTHON_CMD" "$PROJECT_ROOT/compress_font.py" "${fonts[@]}" >/dev/null 2>&1
        log "Compressed ${#fonts[@]} font files in $(basename "$dir")"
    else
        # Only warn if directory has content but no fonts
        local file_count=$(find . -maxdepth 1 -type f | wc -l)
        if [[ $file_count -gt 0 ]]; then
            warn "No fonts found in $dir for compression (found $file_count other files)"
        fi
    fi
    
    cd "$original_dir"
}

finalize_font() {
    local name="$1"
    local dist_dir="$PROJECT_ROOT/$DIST_DIR/$name"
    
    if [[ -d "$dist_dir" ]]; then
        compress_fonts "$dist_dir"
        success "Processed $name fonts"
    fi
    
    # Cleanup temp
    rm -rf "$PROJECT_ROOT/$TMP_DIR/$name"
}

setup_ofl() {
    local dir="$1" dates="$2" holder="$3" name="$4"
    local original_dir="$PWD"
    
    if [[ ! -d "$dir" ]]; then
        warn "Directory $dir does not exist for OFL setup"
        return 1
    fi
    
    cd "$dir"
    [[ ! -f "OFL.txt" ]] && download "https://openfontlicense.org/documents/OFL.txt"
    grep -v "additional Copyright Holder>\|<additional Reserved Font Name>" OFL.txt > LICENSE
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/<dates>/$dates/g; s/<Copyright Holder>/$holder/g; s/ (<URL|email>)//g; s/<Reserved Font Name>/$name/g" LICENSE
    else
        sed -i "s/<dates>/$dates/g; s/<Copyright Holder>/$holder/g; s/ (<URL|email>)//g; s/<Reserved Font Name>/$name/g" LICENSE
    fi
    rm -f OFL.txt
    
    cd "$original_dir"
}

check_deps() {
    local tools=("curl" "unzip" "grep" "sed") missing=()
    for tool in "${tools[@]}"; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done
    [[ ${#missing[@]} -gt 0 ]] && { error "Missing tools: ${missing[*]}"; return 1; }
    command -v "$PYTHON_CMD" >/dev/null 2>&1 || { error "Python not found: $PYTHON_CMD"; return 1; }
    local packages=("fontTools" "zopfli" "brotli") missing_pkg=()
    for pkg in "${packages[@]}"; do
        "$PYTHON_CMD" -c "import $pkg" 2>/dev/null || missing_pkg+=("$pkg")
    done
    [[ ${#missing_pkg[@]} -gt 0 ]] && { error "Missing packages: ${missing_pkg[*]}"; return 1; }
    success "Environment validation passed"
}

# Display summary
display_font_summary() {
    local dist_dir="$1"
    echo
    echo "=========================================="
    echo "           FONT BUILD SUMMARY"
    echo "=========================================="
    echo
    
    printf "%-20s %-10s %-10s %-10s\n" "Font" "OTF Size" "WOFF Size" "WOFF2 Size"
    printf "%-20s %-10s %-10s %-10s\n" "----" "--------" "---------" "----------"
    
    local total_fonts=0
    for font_dir in "$dist_dir"/*; do
        if [[ -d "$font_dir" ]]; then
            local font_name=$(basename "$font_dir")
            local otf_size="N/A" woff_size="N/A" woff2_size="N/A"
            
            local otf_file=$(find "$font_dir" -name "*Math*.otf" -o -name "$font_name*.otf" | head -n1)
            local woff_file=$(find "$font_dir" -name "*Math*.woff" -o -name "$font_name*.woff" | head -n1)
            local woff2_file=$(find "$font_dir" -name "*Math*.woff2" -o -name "$font_name*.woff2" | head -n1)
            
            [[ -f "$otf_file" ]] && otf_size=$(ls -lh "$otf_file" | awk '{print $5}')
            [[ -f "$woff_file" ]] && woff_size=$(ls -lh "$woff_file" | awk '{print $5}')
            [[ -f "$woff2_file" ]] && woff2_size=$(ls -lh "$woff2_file" | awk '{print $5}')
            
            printf "%-20s %-10s %-10s %-10s\n" "$font_name" "$otf_size" "$woff_size" "$woff2_size"
            ((total_fonts++))
        fi
    done
    
    echo
    echo "Total fonts built: $total_fonts"
    echo "=========================================="
    echo
} 