#!/bin/bash
# =============================================================================
# Example usage of the Dataset Information Module
# =============================================================================

# This script demonstrates how to use the info_module.sh with sample data
# Adjust the paths according to your actual PLINK data location

echo "🧬 Dataset Information Module - Example Usage"
echo "=============================================="

# Example 1: Basic usage
echo ""
echo "Example 1: Basic Analysis"
echo "-------------------------"
echo "Command: ./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info"
echo ""

# Example 2: Generate configuration template
echo "Example 2: Generate Configuration Template"
echo "------------------------------------------"
echo "Command: ./info_module.sh --conftemp"
echo "This creates: info_config_template.yaml"
echo ""

# Example 3: Dry run to see what would be executed
echo "Example 3: Dry Run (Preview Commands)"
echo "-------------------------------------"
echo "Command: ./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info --dry-run"
echo ""

# Example 4: Full analysis with configuration
echo "Example 4: Analysis with Configuration File"
echo "-------------------------------------------"
echo "Command: ./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info --config config.yaml"
echo ""

# Example 5: Generate SLURM job script
echo "Example 5: Generate SLURM Job Script"
echo "------------------------------------"
echo "Command: ./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info --slurm"
echo "This creates: results/info/submit_info_module.sh"
echo "Then submit: sbatch results/info/submit_info_module.sh"
echo ""

# Example 6: Help
echo "Example 6: Get Help"
echo "------------------"
echo "Command: ./info_module.sh --help"
echo ""

echo "Expected Output Structure:"
echo "========================="
cat << 'EOF'
results/info/
├── archive/                    # Your original PLINK files
├── logs/                       # Processing logs
├── plots/                      # Visualization files
├── tables/                     # Summary statistics
└── INFO_report_YYYY-MM-DD_HH-MM-SS.html  # Main report
EOF

echo ""
echo "To test with your own data:"
echo "1. Replace '/path/to/your/data' with your actual PLINK prefix"
echo "2. Ensure you have: yourdata.bed, yourdata.bim, yourdata.fam"
echo "3. Run the command from this directory"
echo ""
echo "For SLURM users:"
echo "1. Generate SLURM script with --slurm option"
echo "2. Edit the generated script to adjust resource requirements"
echo "3. Submit with: sbatch results/info/submit_info_module.sh"
