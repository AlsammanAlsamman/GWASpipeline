#!/bin/bash
# =============================================================================
# PLINK Data Fixer Module - Example Usage Script
# PURPOSE: Demonstrate various usage scenarios for the fixer module
# AUTHOR: Alsamman M. Alsamman
# =============================================================================

echo "🔧 PLINK Data Fixer Module - Example Usage"
echo "=========================================="

# Set paths (adjust these to your actual data)
SCRIPT_DIR="$(dirname "$0")"
EXAMPLE_DATA="/path/to/your/plink/data"  # Change this to your actual data path
OUTPUT_DIR="example_outputs"

echo ""
echo "📋 Available Examples:"
echo "1. Basic fixing with default settings"
echo "2. Generate configuration template"
echo "3. Custom configuration usage"
echo "4. SLURM job submission"
echo "5. Sample-only fixing"
echo "6. SNP-only fixing"
echo "7. Dry run (check what would be fixed)"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo ""
echo "Example 1: Basic Fixing with Default Settings"
echo "=============================================="
echo "Command:"
echo "./fixer_module.sh --bfile ${EXAMPLE_DATA} --out ${OUTPUT_DIR}/basic_fixed"
echo ""
echo "This will:"
echo "- Fix duplicate sample IDs"
echo "- Fix invalid characters in sample names"
echo "- Replace duplicate rsIDs with '.'"
echo "- Remove SNPs with duplicate chr:pos (keeping first)"
echo "- Generate comprehensive reports and statistics"
echo ""

echo "Example 2: Generate Configuration Template"
echo "========================================="
echo "Command:"
echo "./fixer_module.sh --conftemp"
echo ""
echo "This creates 'fixer_config_template.yaml' with all available options"
echo ""

echo "Example 3: Custom Configuration Usage"
echo "===================================="
echo "First, create a custom configuration:"
cat << 'EOF' > "${OUTPUT_DIR}/custom_fixer_config.yaml"
# Custom Fixer Configuration
sample_fixing:
  fix_duplicates: true
  fix_invalid_chars: true
  allowed_chars: "A-Za-z0-9_"  # No hyphens allowed
  duplicate_suffix: "_duplicate"

snp_fixing:
  fix_duplicate_rsid: true
  fix_duplicate_chrpos: false  # Don't remove duplicate positions
  keep_first_duplicate: true

output:
  generate_reports: true
  archive_originals: true
  create_plots: false  # Disable plots
EOF

echo "Command:"
echo "./fixer_module.sh --bfile ${EXAMPLE_DATA} --out ${OUTPUT_DIR}/custom_fixed --config ${OUTPUT_DIR}/custom_fixer_config.yaml"
echo ""

echo "Example 4: SLURM Job Submission"
echo "==============================="
echo "Command:"
echo "./fixer_module.sh --bfile ${EXAMPLE_DATA} --out ${OUTPUT_DIR}/slurm_fixed --submit"
echo ""
echo "This will:"
echo "- Generate a SLURM job script"
echo "- Submit the job to the queue"
echo "- Send email notifications on completion"
echo ""

echo "Example 5: Sample-Only Fixing"
echo "============================="
cat << 'EOF' > "${OUTPUT_DIR}/sample_only_config.yaml"
# Sample-only fixing configuration
sample_fixing:
  fix_duplicates: true
  fix_invalid_chars: true
  allowed_chars: "A-Za-z0-9_-"
  duplicate_suffix: "_dup"

snp_fixing:
  fix_duplicate_rsid: false  # Disable SNP fixing
  fix_duplicate_chrpos: false
  keep_first_duplicate: true

output:
  generate_reports: true
  archive_originals: true
  create_plots: true
EOF

echo "Command:"
echo "./fixer_module.sh --bfile ${EXAMPLE_DATA} --out ${OUTPUT_DIR}/sample_fixed --config ${OUTPUT_DIR}/sample_only_config.yaml"
echo ""

echo "Example 6: SNP-Only Fixing"
echo "=========================="
cat << 'EOF' > "${OUTPUT_DIR}/snp_only_config.yaml"
# SNP-only fixing configuration
sample_fixing:
  fix_duplicates: false  # Disable sample fixing
  fix_invalid_chars: false
  allowed_chars: "A-Za-z0-9_-"
  duplicate_suffix: "_dup"

snp_fixing:
  fix_duplicate_rsid: true
  fix_duplicate_chrpos: true
  keep_first_duplicate: false  # Remove ALL duplicate chr:pos

output:
  generate_reports: true
  archive_originals: true
  create_plots: true
EOF

echo "Command:"
echo "./fixer_module.sh --bfile ${EXAMPLE_DATA} --out ${OUTPUT_DIR}/snp_fixed --config ${OUTPUT_DIR}/snp_only_config.yaml"
echo ""

echo "Example 7: Check Input Data Quality (Dry Run)"
echo "============================================="
echo "To check what issues exist in your data without fixing them:"
echo ""
echo "# Check sample issues:"
echo "./sample_fixer.sh --fam ${EXAMPLE_DATA}.fam --out ${OUTPUT_DIR}/check_samples"
echo ""
echo "# Check SNP issues:"
echo "./snp_fixer.sh --bim ${EXAMPLE_DATA}.bim --out ${OUTPUT_DIR}/check_snps"
echo ""

echo "🔍 Understanding the Output"
echo "=========================="
echo ""
echo "After running the fixer module, you'll find:"
echo ""
echo "📁 results/fixer/"
echo "├── archive/                    # Original files (backup)"
echo "├── logs/                       # Processing logs"
echo "├── plots/                      # Visualization plots"
echo "│   ├── FIXER_snp_distribution.png"
echo "│   └── FIXER_snp_distribution.pdf"
echo "├── tables/                     # Reports and statistics"
echo "│   ├── FIXER_sample_changes.tsv"
echo "│   ├── FIXER_sample_stats.md"
echo "│   ├── FIXER_snp_changes.tsv"
echo "│   ├── FIXER_snp_stats.md"
echo "│   └── FIXER_comprehensive_report.html"
echo "├── output_fixed.bed            # Fixed genotype data"
echo "├── output_fixed.bim            # Fixed marker information"
echo "└── output_fixed.fam            # Fixed sample information"
echo ""

echo "📊 Key Reports to Review:"
echo "========================"
echo ""
echo "1. FIXER_comprehensive_report.html"
echo "   - Interactive HTML report with all statistics"
echo "   - Open in web browser for best experience"
echo ""
echo "2. FIXER_sample_changes.tsv"
echo "   - Detailed log of sample ID changes"
echo "   - Shows original vs new sample names"
echo ""
echo "3. FIXER_snp_changes.tsv"
echo "   - Detailed log of SNP changes"
echo "   - Shows which SNPs were modified or removed"
echo ""
echo "4. Processing logs in logs/ directory"
echo "   - Complete processing history with timestamps"
echo "   - Useful for troubleshooting"
echo ""

echo "🚀 Next Steps After Fixing"
echo "=========================="
echo ""
echo "After running the fixer module:"
echo ""
echo "1. Review the comprehensive HTML report"
echo "2. Check the detailed change logs"
echo "3. Validate the fixed files with your downstream tools"
echo "4. Proceed with quality control or analysis pipeline"
echo ""
echo "Example workflow continuation:"
echo "./qc_module.sh --bfile ${OUTPUT_DIR}/basic_fixed --out qc_results"
echo ""

echo "⚠️ Important Notes"
echo "=================="
echo ""
echo "- Always backup your original data before running fixes"
echo "- Review change reports to understand what was modified"
echo "- Test with a small subset first for large datasets"
echo "- Check that downstream tools accept the fixed file formats"
echo "- The 'archive' directory contains your original files"
echo ""

echo "To run any of these examples, modify the EXAMPLE_DATA path at the top of this script"
echo "and uncomment the desired example commands."

# Uncomment the following lines to actually run an example:
# echo ""
# echo "🏃 Running Example 2: Generate Configuration Template"
# echo "===================================================="
# "${SCRIPT_DIR}/fixer_module.sh" --conftemp
