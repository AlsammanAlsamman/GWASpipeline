#!/bin/bash
# =============================================================================
# HPC Module Discovery Script
# =============================================================================
# This script helps identify available modules on your HPC system

echo "🔍 HPC Module Discovery"
echo "======================="
echo "Date: $(date)"
echo ""

# Check if module system is available
if ! command -v module &> /dev/null; then
    echo "❌ Module system not available on this system"
    echo "Tools must be installed in standard locations or PATH"
    exit 1
fi

echo "✅ Module system detected"
echo ""

# Function to search for modules
search_modules() {
    local tool="$1"
    echo "Searching for $tool modules:"
    echo "----------------------------"
    
    # Try different search approaches
    if module avail "$tool" 2>&1 | grep -q "$tool"; then
        echo "Found $tool modules:"
        module avail "$tool" 2>&1 | grep "$tool" | head -10
    elif module avail 2>&1 | grep -i "$tool" | head -5; then
        echo "Found $tool-related modules (case-insensitive):"
        module avail 2>&1 | grep -i "$tool" | head -5
    else
        echo "❌ No $tool modules found"
    fi
    echo ""
}

# Search for commonly needed genomic analysis tools
tools=("plink" "R" "python" "bcftools" "vcftools" "htslib" "samtools" "bedtools")

echo "🔍 Searching for genomic analysis modules:"
echo "=========================================="
echo ""

for tool in "${tools[@]}"; do
    search_modules "$tool"
done

echo "🧪 Testing module loading:"
echo "=========================="
echo ""

# Test loading some modules that might be available
test_modules=("plink" "R" "python" "python3" "bcftools" "vcftools" "htslib")

for mod in "${test_modules[@]}"; do
    echo "Testing: $mod"
    if module load "$mod" 2>/dev/null; then
        echo "  ✅ Successfully loaded: $mod"
        # Check what version was loaded
        case "$mod" in
            "plink")
                if command -v plink &> /dev/null; then
                    echo "     Found plink at: $(which plink)"
                fi
                ;;
            "R")
                if command -v R &> /dev/null; then
                    echo "     Found R at: $(which R)"
                fi
                ;;
            "python"|"python3")
                if command -v python &> /dev/null; then
                    echo "     Found python at: $(which python)"
                fi
                if command -v python3 &> /dev/null; then
                    echo "     Found python3 at: $(which python3)"
                fi
                ;;
            *)
                if command -v "$mod" &> /dev/null; then
                    echo "     Found $mod at: $(which $mod)"
                fi
                ;;
        esac
        module unload "$mod" 2>/dev/null
    else
        echo "  ❌ Failed to load: $mod"
    fi
    echo ""
done

echo "📋 Current module environment:"
echo "============================="
module list 2>&1 || echo "No modules currently loaded"
echo ""

echo "💡 Recommendations:"
echo "=================="
echo "Based on your system, create a custom config file with:"
echo ""

# Generate a custom config based on what we found
cat << 'EOF'
modules:
  load_modules: true
  module_commands:
    # Add the modules that worked from the test above
    # Example:
    # - "module load plink"
    # - "module load R"
    # - "module load python3"
    # - "module load vcftools"
    # - "module load htslib"

EOF

echo "🚀 Next steps:"
echo "============="
echo "1. Review the modules that loaded successfully above"
echo "2. Update your config file with the working module names"
echo "3. Test the pipeline with your custom configuration"
echo ""
echo "Example command:"
echo "./info_module.sh --plink-prefix your_data --output-dir results/info --config custom_config.yaml"
