#!/bin/bash

#####################################################################
# Image Optimization Script
# Purpose: Optimize JPG/PNG images to WebP + optimized JPG
# Usage: ./optimize-image.sh <image-file> [size] [quality]
#####################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_SIZE=240
DEFAULT_QUALITY=80

# Function to display usage
usage() {
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 <image-file> [size] [quality]"
    echo ""
    echo -e "${BLUE}Parameters:${NC}"
    echo "  image-file  : Path to the image file to optimize (required)"
    echo "  size        : Target size in pixels (width=height, default: 240)"
    echo "  quality     : Quality setting 1-100 (default: 80)"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 photo.jpg"
    echo "  $0 photo.jpg 300"
    echo "  $0 photo.jpg 300 85"
    echo ""
    exit 1
}

# Check if required tools are installed
check_dependencies() {
    local missing=()
    
    if ! command -v cwebp &> /dev/null; then
        missing+=("cwebp (webp)")
    fi
    
    if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
        missing+=("ImageMagick")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required tools:${NC}"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Install with: brew install webp imagemagick"
        exit 1
    fi
}

# Function to get file size in human-readable format
get_file_size() {
    local file=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$file" | awk '{
            if ($1 < 1024) printf "%.0f B", $1
            else if ($1 < 1048576) printf "%.1f KB", $1/1024
            else printf "%.1f MB", $1/1048576
        }'
    else
        stat -c%s "$file" | awk '{
            if ($1 < 1024) printf "%.0f B", $1
            else if ($1 < 1048576) printf "%.1f KB", $1/1024
            else printf "%.1f MB", $1/1048576
        }'
    fi
}

# Main script
main() {
    # Check for help flag
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi
    
    # Check if image file is provided
    if [ -z "$1" ]; then
        echo -e "${RED}Error: No image file specified${NC}"
        echo ""
        usage
    fi
    
    # Check dependencies
    check_dependencies
    
    # Get parameters
    INPUT_FILE="$1"
    SIZE="${2:-$DEFAULT_SIZE}"
    QUALITY="${3:-$DEFAULT_QUALITY}"
    
    # Validate input file exists
    if [ ! -f "$INPUT_FILE" ]; then
        echo -e "${RED}Error: File '$INPUT_FILE' not found${NC}"
        exit 1
    fi
    
    # Get file extension and base name
    FILENAME=$(basename "$INPUT_FILE")
    DIRNAME=$(dirname "$INPUT_FILE")
    BASENAME="${FILENAME%.*}"
    EXTENSION="${FILENAME##*.}"
    
    # Output file paths
    WEBP_FILE="${DIRNAME}/${BASENAME}.webp"
    JPG_FILE="${DIRNAME}/${BASENAME}.jpg"
    
    # Get original file size
    ORIGINAL_SIZE=$(get_file_size "$INPUT_FILE")
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           IMAGE OPTIMIZATION IN PROGRESS              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Input:${NC}     $FILENAME"
    echo -e "${YELLOW}Size:${NC}      Original: $ORIGINAL_SIZE"
    echo -e "${YELLOW}Target:${NC}    ${SIZE}x${SIZE}px @ ${QUALITY}% quality"
    echo ""
    
    # Create WebP version
    echo -e "${GREEN}→${NC} Creating WebP version..."
    if cwebp -q "$QUALITY" -resize "$SIZE" "$SIZE" "$INPUT_FILE" -o "$WEBP_FILE" &>/dev/null; then
        WEBP_SIZE=$(get_file_size "$WEBP_FILE")
        echo -e "  ${GREEN}✓${NC} $BASENAME.webp ($WEBP_SIZE)"
    else
        echo -e "  ${RED}✗${NC} Failed to create WebP"
        exit 1
    fi
    
    # Create optimized JPG version
    echo -e "${GREEN}→${NC} Creating optimized JPG..."
    
    # Use magick if available, otherwise fall back to convert
    if command -v magick &> /dev/null; then
        CONVERT_CMD="magick"
    else
        CONVERT_CMD="convert"
    fi
    
    if $CONVERT_CMD "$INPUT_FILE" -resize "${SIZE}x${SIZE}^" -gravity center -extent "${SIZE}x${SIZE}" -quality "$QUALITY" "$JPG_FILE" 2>/dev/null; then
        JPG_SIZE=$(get_file_size "$JPG_FILE")
        echo -e "  ${GREEN}✓${NC} $BASENAME.jpg ($JPG_SIZE)"
    else
        echo -e "  ${RED}✗${NC} Failed to create optimized JPG"
        exit 1
    fi
    
    # Calculate savings
    ORIGINAL_BYTES=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE" 2>/dev/null)
    WEBP_BYTES=$(stat -f%z "$WEBP_FILE" 2>/dev/null || stat -c%s "$WEBP_FILE" 2>/dev/null)
    JPG_BYTES=$(stat -f%z "$JPG_FILE" 2>/dev/null || stat -c%s "$JPG_FILE" 2>/dev/null)
    
    WEBP_SAVINGS=$(awk "BEGIN {printf \"%.1f\", (1 - $WEBP_BYTES / $ORIGINAL_BYTES) * 100}")
    JPG_SAVINGS=$(awk "BEGIN {printf \"%.1f\", (1 - $JPG_BYTES / $ORIGINAL_BYTES) * 100}")
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    RESULTS                             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Original:${NC}      $ORIGINAL_SIZE"
    echo -e "${YELLOW}WebP:${NC}          $WEBP_SIZE (${GREEN}${WEBP_SAVINGS}% smaller${NC})"
    echo -e "${YELLOW}Optimized JPG:${NC} $JPG_SIZE (${GREEN}${JPG_SAVINGS}% smaller${NC})"
    echo ""
    echo -e "${GREEN}✓ Optimization complete!${NC}"
    echo ""
    echo -e "${BLUE}Files created:${NC}"
    echo -e "  • $WEBP_FILE"
    echo -e "  • $JPG_FILE"
    echo ""
}

# Run main function
main "$@"

