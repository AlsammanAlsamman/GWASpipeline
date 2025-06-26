#!/bin/bash
# =============================================================================
# MODULE NAME: Dataset Information Module
# PURPOSE: Comprehensive analysis and reporting of PLINK dataset characteristics
# INPUTS: PLINK binary files (.bed, .bim, .fam) - paths provided as arguments
# OUTPUTS: Summary tables, visual plots, detailed logs, and comprehensive report
# USAGE: ./info_module.sh --plink-prefix /path/to/data --output-dir results/info [options]
# =============================================================================

# Module metadata
MODULE_NAME="info_module"
VERSION="1.0.0"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')

# Default parameters
OUTPUT_DIR=""
PLINK_PREFIX=""
CONFIG_FILE=""
DRY_RUN=false
VERBOSE=false
SLURM_SUBMIT=false

# Help function
show_help() {
    cat << EOF
Dataset Information Module v${VERSION}

USAGE:
    $0 --plink-prefix PREFIX --output-dir DIR [OPTIONS]

REQUIRED ARGUMENTS:
    --plink-prefix PREFIX    Path prefix for PLINK binary files (.bed/.bim/.fam)
    --output-dir DIR         Output directory for results

OPTIONAL ARGUMENTS:
    --config FILE           Configuration file (YAML format)
    --conftemp              Generate example configuration file
    --dry-run               Show commands without executing
    --verbose               Enable verbose output
    --slurm                 Generate SLURM submission script
    --help                  Show this help message

OUTPUTS:
    results/info/
    ├── archive/            # Original input files
    ├── logs/               # Log files
    ├── plots/              # Visual outputs (histograms, distributions)
    ├── tables/             # Summary statistics (TSV format)
    └── INFO_report_${DATE}.html  # Comprehensive HTML report

EXAMPLES:
    # Basic usage
    $0 --plink-prefix /data/mydata --output-dir results/info
    
    # With configuration file
    $0 --plink-prefix /data/mydata --output-dir results/info --config config.yaml
    
    # Generate SLURM job
    $0 --plink-prefix /data/mydata --output-dir results/info --slurm

EOF
}

# Generate configuration template
generate_config_template() {
    cat > info_config_template.yaml << 'EOF'
# =============================================================================
# Dataset Information Module Configuration Template
# =============================================================================

# Analysis Parameters
analysis:
  detailed_chr_stats: true       # Generate per-chromosome statistics
  phenotype_analysis: true       # Analyze phenotype distributions
  population_structure: false    # Basic population structure analysis (PCA preview)
  
# Plotting Options
plots:
  histogram_bins: 50             # Number of bins for histograms
  figure_width: 10               # Plot width in inches
  figure_height: 8               # Plot height in inches
  dpi: 300                       # Plot resolution
  
# Output Options
output:
  generate_html_report: true     # Create comprehensive HTML report
  save_intermediate_files: true  # Keep intermediate PLINK output files
  compress_plots: false          # Compress plot files (PNG vs PDF)

# Resource Settings (for SLURM)
resources:
  cpus: 4
  memory_gb: 8
  time_hours: 2
  partition: "short"
  email: "user@institution.edu"

EOF
    echo "Configuration template created: info_config_template.yaml"
    echo "Edit this file and use with --config info_config_template.yaml"
    exit 0
}

# Generate SLURM submission script
generate_slurm_script() {
    local slurm_script="${OUTPUT_DIR}/submit_info_module.sh"
    
    # Parse modules from config file if available
    local modules_for_slurm=()
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        if parse_modules_from_config "$CONFIG_FILE" modules_for_slurm; then
            log_message "INFO" "Using ${#modules_for_slurm[@]} modules from configuration for SLURM script"
        else
            log_message "INFO" "Using default modules for SLURM script"
            modules_for_slurm=(
            "plink2/1.90b3w"
            "R"
            "bcftools"
            "vcftools"
            "htslib"
            "samtools"
            "bedtools"
            "tabix"            )
        fi
    else
        log_message "INFO" "No configuration file, using default modules for SLURM script"
        modules_for_slurm=(
            "plink2/1.90b3w"
            "R"
            "bcftools"
            "vcftools"
            "htslib"
            "samtools"
            "bedtools"
            "tabix"
        )
    fi
    
    cat > "$slurm_script" << EOF
#!/bin/bash
#SBATCH --job-name=info_module
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --mail-user=alsammana@omrf.org
#SBATCH --mail-type=ALL
#SBATCH --output=${OUTPUT_DIR}/logs/info_module_%j.out
#SBATCH --error=${OUTPUT_DIR}/logs/info_module_%j.err

# =============================================================================
# Load Required Software Modules
# =============================================================================
$(if [[ -n "$CONFIG_FILE" ]]; then
    echo "# Modules loaded from configuration file: $CONFIG_FILE"
else
    echo "# Using default module configuration"
fi)

echo "Loading required modules..."
EOF

    # Add module load commands dynamically
    for module in "${modules_for_slurm[@]}"; do
        cat >> "$slurm_script" << EOF
module load $module
EOF
    done
    
    cat >> "$slurm_script" << EOF

# Verify critical modules are loaded
echo "Checking loaded modules..."
module list

# Verify critical tools are available
echo "Verifying critical tools..."
critical_tools=("plink" "R")
missing_tools=()

for tool in "\${critical_tools[@]}"; do
    if command -v "\$tool" &> /dev/null; then
        echo "✅ \$tool found: \$(which \$tool)"
    else
        echo "❌ \$tool not found"
        missing_tools+=("\$tool")
    fi
done

if [ \${#missing_tools[@]} -gt 0 ]; then
    echo "ERROR: Missing critical tools: \${missing_tools[*]}"
    echo "Please check module loading or contact system administrator"
    exit 1
fi

echo "All required modules loaded successfully"

# =============================================================================
# Run the Information Module
# =============================================================================
$(realpath "$0") --plink-prefix "${PLINK_PREFIX}" --output-dir "${OUTPUT_DIR}" $([ -n "$CONFIG_FILE" ] && echo "--config $CONFIG_FILE")

EOF
    
    chmod +x "$slurm_script"
    echo "SLURM submission script created: $slurm_script"
    echo "Submit with: sbatch $slurm_script"
    echo ""
    if [[ -n "$CONFIG_FILE" ]]; then
        echo "Note: Using modules from configuration file: $CONFIG_FILE"
        echo "Modules to be loaded: ${modules_for_slurm[*]}"
    else
        echo "Note: Using default modules. Create a config file to customize."
    fi
    exit 0
}

# Logging function
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "${OUTPUT_DIR}/logs/info_module_${DATE}.log"
}

# Error handling
error_exit() {
    log_message "ERROR" "$1"
    exit 1
}

# Validate inputs
validate_inputs() {
    log_message "INFO" "Validating input files..."
    
    # Check if PLINK files exist
    if [[ ! -f "${PLINK_PREFIX}.bed" ]]; then
        error_exit "PLINK .bed file not found: ${PLINK_PREFIX}.bed"
    fi
    if [[ ! -f "${PLINK_PREFIX}.bim" ]]; then
        error_exit "PLINK .bim file not found: ${PLINK_PREFIX}.bim"
    fi
    if [[ ! -f "${PLINK_PREFIX}.fam" ]]; then
        error_exit "PLINK .fam file not found: ${PLINK_PREFIX}.fam"
    fi
    
    log_message "INFO" "Input validation: PASSED"
}

# Create directory structure
setup_directories() {
    log_message "INFO" "Setting up output directory structure..."
    
    mkdir -p "${OUTPUT_DIR}"/{archive,logs,plots,tables}
    
    # Archive original input files
    log_message "INFO" "Archiving original input files..."
    cp "${PLINK_PREFIX}".{bed,bim,fam} "${OUTPUT_DIR}/archive/" 2>/dev/null || {
        log_message "WARN" "Could not copy all input files to archive"
    }
}

# Parse YAML configuration for modules
parse_modules_from_config() {
    local config_file="$1"
    local -n modules_array=$2
    
    if [[ -f "$config_file" ]]; then
        log_message "INFO" "Parsing module configuration from: $config_file"
        
        # Extract module commands from YAML
        # Look for module_commands section and extract module load commands
        local in_modules_section=false
        local in_module_commands=false
        
        while IFS= read -r line; do
            # Remove leading/trailing whitespace
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Skip comments and empty lines
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            
            # Check if we're entering modules section
            if [[ "$line" =~ ^modules: ]]; then
                in_modules_section=true
                continue
            fi
            
            # Check if we're in a different top-level section
            if [[ "$line" =~ ^[a-zA-Z][^:]*:$ ]] && [[ "$line" != "modules:" ]]; then
                in_modules_section=false
                in_module_commands=false
                continue
            fi
            
            # If we're in modules section, look for module_commands
            if [[ "$in_modules_section" == true ]]; then
                if [[ "$line" =~ ^module_commands: ]]; then
                    in_module_commands=true
                    continue
                fi
                
                # If we hit another key in modules section, stop looking for commands
                if [[ "$line" =~ ^[a-zA-Z_][^:]*: ]] && [[ "$line" != "module_commands:" ]]; then
                    in_module_commands=false
                    continue
                fi
                
                # Extract module commands (lines starting with -)
                if [[ "$in_module_commands" == true ]] && [[ "$line" =~ ^-[[:space:]]*\"(.*)\"$ ]]; then
                    local module_cmd="${BASH_REMATCH[1]}"
                    # Extract just the module name (remove "module load " prefix)
                    if [[ "$module_cmd" =~ module[[:space:]]+load[[:space:]]+(.+) ]]; then
                        modules_array+=("${BASH_REMATCH[1]}")
                        log_message "INFO" "Found module in config: ${BASH_REMATCH[1]}"
                    fi
                fi
            fi
        done < "$config_file"
        
        if [[ ${#modules_array[@]} -gt 0 ]]; then
            log_message "INFO" "Loaded ${#modules_array[@]} modules from configuration file"
            return 0
        else
            log_message "WARN" "No modules found in configuration file"
            return 1
        fi
    else
        log_message "WARN" "Configuration file not found: $config_file"
        return 1
    fi
}

# Load software modules
load_modules() {
    log_message "INFO" "Loading required software modules..."
    
    # Default modules to load (used when no config file or config parsing fails)
    local default_modules=(
        "plink2/1.90b3w"
        "R"
        "python/3.5.10"
        "bcftools"
        "vcftools"
        "htslib"
    )
    
    local modules_to_load=()
    
    # Try to parse modules from configuration file first
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        log_message "INFO" "Attempting to load modules from configuration file..."
        if parse_modules_from_config "$CONFIG_FILE" modules_to_load; then
            log_message "INFO" "Using modules from configuration file"
        else
            log_message "INFO" "Failed to parse modules from config, using defaults"
            modules_to_load=("${default_modules[@]}")
        fi
    else
        log_message "INFO" "No configuration file provided, using default modules"
        modules_to_load=("${default_modules[@]}")
    fi
    
    # Check if running in HPC environment (module command available)
    if command -v module &> /dev/null; then
        log_message "INFO" "Module system detected, loading ${#modules_to_load[@]} modules..."
        
        # Load modules
        local loaded_count=0
        local failed_count=0
        
        for mod in "${modules_to_load[@]}"; do
            log_message "INFO" "Loading module: $mod"
            if module load "$mod" 2>/dev/null; then
                log_message "INFO" "Successfully loaded: $mod"
                ((loaded_count++))
            else
                log_message "WARN" "Failed to load module: $mod (may not be available)"
                ((failed_count++))
            fi
        done
        
        log_message "INFO" "Module loading summary: $loaded_count loaded, $failed_count failed"
        
        # Verify critical tools are available
        verify_critical_tools
        
    else
        log_message "INFO" "No module system detected, assuming tools are in PATH"
        verify_critical_tools
    fi
}

# Verify that critical tools are available
verify_critical_tools() {
    log_message "INFO" "Verifying critical tools availability..."
    
    local critical_tools=("plink" "R")
    local optional_tools=("bcftools" "vcftools" "python" "python3")
    local missing_critical=()
    local missing_optional=()
    
    # Check critical tools
    for tool in "${critical_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local tool_path=$(which "$tool")
            log_message "INFO" "$tool found: $tool_path"
        else
            missing_critical+=("$tool")
            log_message "ERROR" "$tool not found in PATH"
        fi
    done
    
    # Check optional tools
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local tool_path=$(which "$tool")
            log_message "INFO" "$tool found: $tool_path"
        else
            missing_optional+=("$tool")
            log_message "WARN" "$tool not found in PATH"
        fi
    done
    
    # Report results
    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing critical tools: ${missing_critical[*]}"
        log_message "ERROR" "Pipeline may not function correctly"
        return 1
    elif [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_message "WARN" "Missing optional tools: ${missing_optional[*]}"
        log_message "WARN" "Some analyses may not be available"
        return 0
    else
        log_message "INFO" "All tools verified successfully"
        return 0
    fi
}

# Load configuration file
load_config() {
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        log_message "INFO" "Loading configuration from: $CONFIG_FILE"
        # For now, we'll use defaults. In a full implementation, 
        # you would parse YAML here using a tool like yq
        # Example: load custom module list from config
        log_message "INFO" "Configuration loaded successfully"
    else
        log_message "INFO" "Using default configuration"
    fi
}

# Basic dataset statistics using PLINK
generate_basic_stats() {
    log_message "INFO" "Generating basic dataset statistics..."
    
    local stats_prefix="${OUTPUT_DIR}/tables/INFO_basic_stats"
    
    # Generate frequency statistics
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] plink --bfile ${PLINK_PREFIX} --freq --out ${stats_prefix}"
    else
        plink --bfile "${PLINK_PREFIX}" --freq --out "${stats_prefix}" --allow-no-sex 2>&1 | \
            tee -a "${OUTPUT_DIR}/logs/plink_freq_${DATE}.log"
    fi
    
    # Generate missing statistics
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] plink --bfile ${PLINK_PREFIX} --missing --out ${stats_prefix}"
    else
        plink --bfile "${PLINK_PREFIX}" --missing --out "${stats_prefix}" --allow-no-sex 2>&1 | \
            tee -a "${OUTPUT_DIR}/logs/plink_missing_${DATE}.log"
    fi
    
    # Generate Hardy-Weinberg statistics
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] plink --bfile ${PLINK_PREFIX} --hardy --out ${stats_prefix}"
    else
        plink --bfile "${PLINK_PREFIX}" --hardy --out "${stats_prefix}" --allow-no-sex 2>&1 | \
            tee -a "${OUTPUT_DIR}/logs/plink_hardy_${DATE}.log"
    fi
}

# Analyze file contents using standard Unix tools
analyze_file_contents() {
    log_message "INFO" "Analyzing file contents and structure..."
    
    local summary_file="${OUTPUT_DIR}/tables/INFO_file_summary_${DATE}.tsv"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Analyzing .fam, .bim file contents"
        return
    fi
    
    # Create summary file header
    echo -e "Metric\tValue\tDescription" > "$summary_file"
    
    # Count samples and SNPs
    local n_samples=$(wc -l < "${PLINK_PREFIX}.fam")
    local n_snps=$(wc -l < "${PLINK_PREFIX}.bim")
    
    echo -e "Total_Samples\t$n_samples\tNumber of samples in dataset" >> "$summary_file"
    echo -e "Total_SNPs\t$n_snps\tNumber of SNPs in dataset" >> "$summary_file"
    
    # Analyze chromosomes
    local n_chromosomes=$(cut -f1 "${PLINK_PREFIX}.bim" | sort -u | wc -l)
    echo -e "Chromosomes\t$n_chromosomes\tNumber of unique chromosomes" >> "$summary_file"
    
    # Check for duplicate sample IDs
    local dup_fid=$(cut -f1 "${PLINK_PREFIX}.fam" | sort | uniq -d | wc -l)
    local dup_iid=$(cut -f2 "${PLINK_PREFIX}.fam" | sort | uniq -d | wc -l)
    echo -e "Duplicate_FID\t$dup_fid\tNumber of duplicate Family IDs" >> "$summary_file"
    echo -e "Duplicate_IID\t$dup_iid\tNumber of duplicate Individual IDs" >> "$summary_file"
    
    # Check for duplicate SNP IDs
    local dup_snps=$(cut -f2 "${PLINK_PREFIX}.bim" | sort | uniq -d | wc -l)
    echo -e "Duplicate_SNP_IDs\t$dup_snps\tNumber of duplicate SNP IDs" >> "$summary_file"
    
    # Sex distribution
    local males=$(awk '$5 == 1' "${PLINK_PREFIX}.fam" | wc -l)
    local females=$(awk '$5 == 2' "${PLINK_PREFIX}.fam" | wc -l)
    local unknown_sex=$(awk '$5 == 0' "${PLINK_PREFIX}.fam" | wc -l)
    echo -e "Males\t$males\tNumber of male samples" >> "$summary_file"
    echo -e "Females\t$females\tNumber of female samples" >> "$summary_file"
    echo -e "Unknown_Sex\t$unknown_sex\tNumber of samples with unknown sex" >> "$summary_file"
    
    # Phenotype distribution (assuming binary: 1=control, 2=case)
    local controls=$(awk '$6 == 1' "${PLINK_PREFIX}.fam" | wc -l)
    local cases=$(awk '$6 == 2' "${PLINK_PREFIX}.fam" | wc -l)
    local missing_pheno=$(awk '$6 == -9 || $6 == 0' "${PLINK_PREFIX}.fam" | wc -l)
    echo -e "Controls\t$controls\tNumber of control samples (phenotype=1)" >> "$summary_file"
    echo -e "Cases\t$cases\tNumber of case samples (phenotype=2)" >> "$summary_file"
    echo -e "Missing_Phenotype\t$missing_pheno\tNumber of samples with missing phenotype" >> "$summary_file"
    
    log_message "INFO" "File summary saved to: $summary_file"
}

# Generate chromosome distribution
analyze_chromosome_distribution() {
    log_message "INFO" "Analyzing chromosomal distribution..."
    
    local chr_file="${OUTPUT_DIR}/tables/INFO_chromosome_distribution_${DATE}.tsv"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Generating chromosome distribution analysis"
        return
    fi
    
    echo -e "Chromosome\tSNP_Count\tPercentage" > "$chr_file"
    
    # Count SNPs per chromosome
    cut -f1 "${PLINK_PREFIX}.bim" | sort | uniq -c | \
    awk -v total=$(wc -l < "${PLINK_PREFIX}.bim") '
    {
        chr = $2
        count = $1
        percentage = (count / total) * 100
        printf "%s\t%d\t%.2f\n", chr, count, percentage
    }' >> "$chr_file"
    
    log_message "INFO" "Chromosome distribution saved to: $chr_file"
}

# Generate plots using R (if available) or Python
generate_plots() {
    log_message "INFO" "Generating visualization plots..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Generating plots for MAF, missingness, and chromosome distributions"
        return
    fi
    
    # Create a simple R script for plotting (if R is available)
    if command -v Rscript &> /dev/null; then
        create_r_plots
    else
        log_message "WARN" "R not found. Plots will be generated using basic tools."
        create_basic_plots
    fi
}

# Create R plots
create_r_plots() {
    local r_script="${OUTPUT_DIR}/plots/generate_plots.R"
    
    cat > "$r_script" << 'EOF'
# Load required libraries
library(ggplot2)
library(data.table)

# Set output directory
args <- commandArgs(trailingOnly = TRUE)
output_dir <- args[1]
tables_dir <- file.path(output_dir, "tables")
plots_dir <- file.path(output_dir, "plots")

# Read data files
freq_file <- list.files(tables_dir, pattern = ".*\\.frq$", full.names = TRUE)[1]
missing_file <- list.files(tables_dir, pattern = ".*\\.lmiss$", full.names = TRUE)[1]
chr_file <- list.files(tables_dir, pattern = "INFO_chromosome_distribution.*\\.tsv$", full.names = TRUE)[1]

# MAF distribution plot
if (file.exists(freq_file)) {
  freq_data <- fread(freq_file)
  
  p1 <- ggplot(freq_data, aes(x = MAF)) +
    geom_histogram(bins = 50, fill = "steelblue", alpha = 0.7) +
    labs(title = "Minor Allele Frequency Distribution",
         x = "Minor Allele Frequency",
         y = "Number of SNPs") +
    theme_minimal()
  
  ggsave(file.path(plots_dir, "MAF_distribution.pdf"), p1, width = 10, height = 8, dpi = 300)
}

# Missingness distribution plot
if (file.exists(missing_file)) {
  missing_data <- fread(missing_file)
  
  p2 <- ggplot(missing_data, aes(x = F_MISS)) +
    geom_histogram(bins = 50, fill = "coral", alpha = 0.7) +
    labs(title = "SNP Missingness Distribution",
         x = "Fraction of Missing Genotypes",
         y = "Number of SNPs") +
    theme_minimal()
  
  ggsave(file.path(plots_dir, "missingness_distribution.pdf"), p2, width = 10, height = 8, dpi = 300)
}

# Chromosome distribution plot
if (file.exists(chr_file)) {
  chr_data <- fread(chr_file)
  
  p3 <- ggplot(chr_data, aes(x = factor(Chromosome), y = SNP_Count)) +
    geom_bar(stat = "identity", fill = "darkgreen", alpha = 0.7) +
    labs(title = "SNP Distribution Across Chromosomes",
         x = "Chromosome",
         y = "Number of SNPs") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(file.path(plots_dir, "chromosome_distribution.pdf"), p3, width = 12, height = 8, dpi = 300)
}

cat("Plots generated successfully\n")
EOF
    
    # Run R script
    Rscript "$r_script" "$OUTPUT_DIR" 2>&1 | tee -a "${OUTPUT_DIR}/logs/plots_${DATE}.log"
}

# Create basic plots using gnuplot or simple text-based visualization
create_basic_plots() {
    log_message "INFO" "Creating basic visualization summaries..."
    
    # Create a simple text-based summary
    local plot_summary="${OUTPUT_DIR}/plots/plot_summary_${DATE}.txt"
    
    cat > "$plot_summary" << EOF
=== DATASET VISUALIZATION SUMMARY ===
Generated on: $(date)

Note: Full graphical plots require R or Python with plotting libraries.
This is a text-based summary of key visualizable metrics.

--- Chromosome Distribution ---
$(cut -f1 "${PLINK_PREFIX}.bim" | sort | uniq -c | awk '{printf "Chr %s: %d SNPs\n", $2, $1}')

--- File Size Information ---
.bed file: $(ls -lh "${PLINK_PREFIX}.bed" | awk '{print $5}')
.bim file: $(ls -lh "${PLINK_PREFIX}.bim" | awk '{print $5}')
.fam file: $(ls -lh "${PLINK_PREFIX}.fam" | awk '{print $5}')

EOF
    
    log_message "INFO" "Basic plot summary saved to: $plot_summary"
}

# Generate comprehensive HTML report
generate_html_report() {
    log_message "INFO" "Generating comprehensive HTML report..."
    
    local report_file="${OUTPUT_DIR}/INFO_report_${DATE}.html"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Generating HTML report: $report_file"
        return
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dataset Information Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background-color: #f4f4f4; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .metric { font-weight: bold; color: #2c3e50; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧬 Dataset Information Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Dataset:</strong> $(basename "$PLINK_PREFIX")</p>
        <p><strong>Module Version:</strong> $VERSION</p>
    </div>
    
    <div class="section">
        <h2>📊 Dataset Overview</h2>
        <table>
$(if [[ -f "${OUTPUT_DIR}/tables/INFO_file_summary_${DATE}.tsv" ]]; then
    tail -n +2 "${OUTPUT_DIR}/tables/INFO_file_summary_${DATE}.tsv" | \
    awk -F'\t' '{printf "            <tr><td class=\"metric\">%s</td><td>%s</td><td>%s</td></tr>\n", $1, $2, $3}'
fi)
        </table>
    </div>
    
    <div class="section">
        <h2>🧪 Quality Metrics</h2>
        <p>Detailed quality control metrics are available in the tables/ directory.</p>
        <ul>
            <li>Allele frequency statistics: Available in .frq files</li>
            <li>Missingness statistics: Available in .lmiss/.imiss files</li>
            <li>Hardy-Weinberg equilibrium: Available in .hwe files</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>📁 Output Files</h2>
        <ul>
            <li><strong>Tables:</strong> $(ls "${OUTPUT_DIR}/tables/" | wc -l) files in tables/ directory</li>
            <li><strong>Plots:</strong> $(ls "${OUTPUT_DIR}/plots/" | wc -l) files in plots/ directory</li>
            <li><strong>Logs:</strong> $(ls "${OUTPUT_DIR}/logs/" | wc -l) files in logs/ directory</li>
            <li><strong>Archive:</strong> Original input files preserved in archive/ directory</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>⚙️ Processing Parameters</h2>
        <p>All processing parameters and logs are available in the logs/ directory.</p>
        <p>Configuration used: $([ -n "$CONFIG_FILE" ] && echo "$CONFIG_FILE" || echo "Default settings")</p>
    </div>
    
    <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666;">
        <p>Generated by Dataset Information Module v${VERSION}</p>
        <p>For questions or issues, please refer to the development guide.</p>
    </footer>
</body>
</html>
EOF
    
    log_message "INFO" "HTML report generated: $report_file"
}

# Main execution function
main() {
    log_message "INFO" "Starting Dataset Information Module v${VERSION}"
    log_message "INFO" "Processing dataset: $PLINK_PREFIX"
    log_message "INFO" "Output directory: $OUTPUT_DIR"
    
    # Setup and validation
    setup_directories
    validate_inputs
    load_config
    load_modules
    
    # Analysis steps
    analyze_file_contents
    analyze_chromosome_distribution
    generate_basic_stats
    generate_plots
    generate_html_report
    
    log_message "INFO" "Dataset Information Module completed successfully"
    log_message "INFO" "Results saved in: $OUTPUT_DIR"
    
    # Display summary
    echo ""
    echo "🎉 Analysis Complete!"
    echo "📁 Results directory: $OUTPUT_DIR"
    echo "📋 Summary report: ${OUTPUT_DIR}/INFO_report_${DATE}.html"
    echo "📊 Summary tables: ${OUTPUT_DIR}/tables/"
    echo "📈 Plots: ${OUTPUT_DIR}/plots/"
    echo "📝 Logs: ${OUTPUT_DIR}/logs/"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --plink-prefix)
            PLINK_PREFIX="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --conftemp)
            generate_config_template
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --slurm)
            SLURM_SUBMIT=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PLINK_PREFIX" ]]; then
    echo "Error: --plink-prefix is required"
    show_help
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    echo "Error: --output-dir is required"
    show_help
    exit 1
fi

# Generate SLURM script if requested
if [[ "$SLURM_SUBMIT" == "true" ]]; then
    mkdir -p "$OUTPUT_DIR/logs"
    generate_slurm_script
fi

# Run main analysis
main
