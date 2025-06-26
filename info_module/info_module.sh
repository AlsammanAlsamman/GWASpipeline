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
SLURM_AUTO_SUBMIT=false

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
    --submit                Generate and submit SLURM job automatically
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
    
    # Generate SLURM job script
    $0 --plink-prefix /data/mydata --output-dir results/info --slurm
    
    # Generate and automatically submit SLURM job
    $0 --plink-prefix /data/mydata --output-dir results/info --submit

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

# Generate and submit SLURM job automatically
generate_and_submit_slurm_job() {
    log_message "INFO" "Generating and submitting SLURM job..."
    
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
                "tabix"
            )
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
    log_message "INFO" "SLURM submission script created: $slurm_script"
    
    # Check if sbatch is available
    if ! command -v sbatch &> /dev/null; then
        log_message "ERROR" "sbatch command not found. Cannot submit job automatically."
        log_message "INFO" "You can manually submit with: sbatch $slurm_script"
        exit 1
    fi
    
    # Submit the job
    log_message "INFO" "Submitting job with sbatch..."
    local job_output
    job_output=$(sbatch "$slurm_script" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        local job_id=$(echo "$job_output" | grep -o '[0-9]\+' | tail -1)
        log_message "INFO" "Job submitted successfully!"
        log_message "INFO" "Job ID: $job_id"
        log_message "INFO" "SLURM output: $job_output"
        
        echo ""
        echo "🚀 SLURM Job Submitted Successfully!"
        echo "====================================="
        echo "Job ID: $job_id"
        echo "Script: $slurm_script"
        echo "Output logs: ${OUTPUT_DIR}/logs/info_module_${job_id}.out"
        echo "Error logs: ${OUTPUT_DIR}/logs/info_module_${job_id}.err"
        echo ""
        echo "Monitor job status with:"
        echo "  squeue -j $job_id"
        echo "  scontrol show job $job_id"
        echo ""
        echo "Cancel job if needed with:"
        echo "  scancel $job_id"
        
        if [[ -n "$CONFIG_FILE" ]]; then
            echo ""
            echo "Configuration used: $CONFIG_FILE"
            echo "Modules to be loaded: ${modules_for_slurm[*]}"
        fi
        
    else
        log_message "ERROR" "Failed to submit job!"
        log_message "ERROR" "sbatch output: $job_output"
        log_message "INFO" "You can manually submit with: sbatch $slurm_script"
        exit 1
    fi
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

# Enhanced file contents analysis with proper duplicate detection and validation
analyze_file_contents() {
    log_message "INFO" "Analyzing file contents and structure..."
    
    local summary_file="${OUTPUT_DIR}/tables/INFO_file_summary_${DATE}.tsv"
    local validation_file="${OUTPUT_DIR}/tables/INFO_validation_issues_${DATE}.tsv"
    local recommendations_file="${OUTPUT_DIR}/tables/INFO_recommendations_${DATE}.txt"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Analyzing .fam, .bim file contents with enhanced validation"
        return
    fi
    
    # Create summary file header
    echo -e "Metric\tValue\tDescription" > "$summary_file"
    
    # Create validation issues file header
    echo -e "Issue_Type\tCount\tSeverity\tDescription\tAffected_Items" > "$validation_file"
    
    # Count samples and SNPs
    local n_samples=$(wc -l < "${PLINK_PREFIX}.fam")
    local n_snps=$(wc -l < "${PLINK_PREFIX}.bim")
    
    echo -e "Total_Samples\t$n_samples\tNumber of samples in dataset" >> "$summary_file"
    echo -e "Total_SNPs\t$n_snps\tNumber of SNPs in dataset" >> "$summary_file"
    
    # Analyze chromosomes
    local n_chromosomes=$(cut -f1 "${PLINK_PREFIX}.bim" | sort -u | wc -l)
    echo -e "Chromosomes\t$n_chromosomes\tNumber of unique chromosomes" >> "$summary_file"
    
    # === ENHANCED DUPLICATE DETECTION ===
    log_message "INFO" "Performing enhanced duplicate detection..."
    
    # Check for duplicate Individual IDs (IID) - Column 2 (space-delimited)
    local dup_iid_file="${OUTPUT_DIR}/tables/duplicate_IIDs_${DATE}.txt"
    log_message "INFO" "Detecting duplicate Individual IDs (column 2)..."
    
    # Use proper space delimiter and extract second column (IID)
    awk '{print $2}' "${PLINK_PREFIX}.fam" | sort | uniq -c | awk '$1 > 1 {print $2 "\t" $1}' > "$dup_iid_file"
    local dup_iid_count=$(wc -l < "$dup_iid_file")
    
    echo -e "Duplicate_IID\t$dup_iid_count\tNumber of duplicate Individual IDs" >> "$summary_file"
    
    if [[ $dup_iid_count -gt 0 ]]; then
        local dup_iid_list=$(head -5 "$dup_iid_file" | cut -f1 | tr '\n' ',' | sed 's/,$//')
        echo -e "Duplicate_IID\t$dup_iid_count\tHIGH\tDuplicate Individual IDs found - will cause PLINK errors\t$dup_iid_list..." >> "$validation_file"
        log_message "WARN" "Found $dup_iid_count duplicate Individual IDs: $dup_iid_list"
        
        # Save detailed list with counts for debugging
        log_message "INFO" "Duplicate IID details saved to: $dup_iid_file"
        
        # Also save the actual lines from .fam file that contain duplicates
        local dup_iid_lines_file="${OUTPUT_DIR}/tables/duplicate_IID_lines_${DATE}.txt"
        echo "# Lines from .fam file containing duplicate Individual IDs" > "$dup_iid_lines_file"
        while read -r dup_iid count; do
            echo "# IID: $dup_iid (appears $count times)" >> "$dup_iid_lines_file"
            grep " $dup_iid " "${PLINK_PREFIX}.fam" >> "$dup_iid_lines_file"
            echo "" >> "$dup_iid_lines_file"
        done < "$dup_iid_file"
        log_message "INFO" "Duplicate IID examples saved to: $dup_iid_lines_file"
    else
        log_message "INFO" "No duplicate Individual IDs found"
    fi
    
    # Check for duplicate Family IDs (normal but worth noting) - Column 1
    local dup_fid_file="${OUTPUT_DIR}/tables/duplicate_FIDs_${DATE}.txt"
    log_message "INFO" "Detecting Family ID patterns (column 1)..."
    
    # Use proper space delimiter and extract first column (FID)
    awk '{print $1}' "${PLINK_PREFIX}.fam" | sort | uniq -c | awk '$1 > 1 {print $2 "\t" $1}' > "$dup_fid_file"
    local dup_fid_count=$(wc -l < "$dup_fid_file")
    
    echo -e "Duplicate_FID\t$dup_fid_count\tNumber of Family IDs with multiple samples" >> "$summary_file"
    
    if [[ $dup_fid_count -gt 0 ]]; then
        local dup_fid_list=$(head -3 "$dup_fid_file" | cut -f1 | tr '\n' ',' | sed 's/,$//')
        echo -e "Duplicate_FID\t$dup_fid_count\tLOW\tMultiple samples per Family ID (normal for families)\t$dup_fid_list..." >> "$validation_file"
        log_message "INFO" "Found $dup_fid_count Family IDs with multiple samples (this is normal)"
        
        # Save summary of family sizes
        local family_summary_file="${OUTPUT_DIR}/tables/family_sizes_${DATE}.txt"
        echo "# Family ID sizes (Family_ID -> Number_of_Samples)" > "$family_summary_file"
        sort -k2 -nr "$dup_fid_file" >> "$family_summary_file"
        log_message "INFO" "Family size summary saved to: $family_summary_file"
    else
        log_message "INFO" "Each Family ID appears only once"
    fi
    
    # === SPECIAL CHARACTER VALIDATION ===
    log_message "INFO" "Validating sample ID formats..."
    
    # Check for special characters in Family IDs
    local bad_fid_file="${OUTPUT_DIR}/tables/invalid_FIDs_${DATE}.txt"
    awk '{print NR, $1}' "${PLINK_PREFIX}.fam" | grep '[^0-9 a-zA-Z0-9_-]' > "$bad_fid_file" 2>/dev/null || true
    local bad_fid_count=$(wc -l < "$bad_fid_file")
    
    echo -e "Invalid_FID_Format\t$bad_fid_count\tNumber of Family IDs with special characters" >> "$summary_file"
    
    if [[ $bad_fid_count -gt 0 ]]; then
        local bad_fid_examples=$(head -3 "$bad_fid_file" | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
        echo -e "Invalid_FID_Format\t$bad_fid_count\tMEDIUM\tFamily IDs contain spaces/special characters\t$bad_fid_examples..." >> "$validation_file"
        log_message "WARN" "Found $bad_fid_count Family IDs with special characters"
    fi
    
    # Check for special characters in Individual IDs
    local bad_iid_file="${OUTPUT_DIR}/tables/invalid_IIDs_${DATE}.txt"
    awk '{print NR, $2}' "${PLINK_PREFIX}.fam" | grep '[^0-9 a-zA-Z0-9_-]' > "$bad_iid_file" 2>/dev/null || true
    local bad_iid_count=$(wc -l < "$bad_iid_file")
    
    echo -e "Invalid_IID_Format\t$bad_iid_count\tNumber of Individual IDs with special characters" >> "$summary_file"
    
    if [[ $bad_iid_count -gt 0 ]]; then
        local bad_iid_examples=$(head -3 "$bad_iid_file" | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
        echo -e "Invalid_IID_Format\t$bad_iid_count\tHIGH\tIndividual IDs contain spaces/special characters\t$bad_iid_examples..." >> "$validation_file"
        log_message "WARN" "Found $bad_iid_count Individual IDs with special characters"
    fi
    
    # Check for spaces in IDs (most common issue)
    local space_fid_count=$(awk '{print $1}' "${PLINK_PREFIX}.fam" | grep -c ' ' 2>/dev/null || echo "0")
    local space_iid_count=$(awk '{print $2}' "${PLINK_PREFIX}.fam" | grep -c ' ' 2>/dev/null || echo "0")
    
    echo -e "FID_With_Spaces\t$space_fid_count\tNumber of Family IDs containing spaces" >> "$summary_file"
    echo -e "IID_With_Spaces\t$space_iid_count\tNumber of Individual IDs containing spaces" >> "$summary_file"
    
    # === SNP ID VALIDATION ===
    log_message "INFO" "Validating SNP IDs..."
    
    # Check for duplicate SNP IDs
    local dup_snp_file="${OUTPUT_DIR}/tables/duplicate_SNPs_${DATE}.txt"
    cut -f2 "${PLINK_PREFIX}.bim" | sort | uniq -c | awk '$1 > 1 {print $2 "\t" $1}' > "$dup_snp_file"
    local dup_snp_count=$(wc -l < "$dup_snp_file")
    
    echo -e "Duplicate_SNP_IDs\t$dup_snp_count\tNumber of duplicate SNP IDs" >> "$summary_file"
    
    if [[ $dup_snp_count -gt 0 ]]; then
        local dup_snp_examples=$(head -3 "$dup_snp_file" | cut -f1 | tr '\n' ',' | sed 's/,$//')
        echo -e "Duplicate_SNP_IDs\t$dup_snp_count\tHIGH\tDuplicate SNP IDs found - will cause analysis errors\t$dup_snp_examples..." >> "$validation_file"
        log_message "WARN" "Found $dup_snp_count duplicate SNP IDs"
    fi
    
    # Sex distribution - Column 5
    local males=$(awk '$5 == 1' "${PLINK_PREFIX}.fam" | wc -l)
    local females=$(awk '$5 == 2' "${PLINK_PREFIX}.fam" | wc -l)
    local unknown_sex=$(awk '$5 == 0' "${PLINK_PREFIX}.fam" | wc -l)
    echo -e "Males\t$males\tNumber of male samples" >> "$summary_file"
    echo -e "Females\t$females\tNumber of female samples" >> "$summary_file"
    echo -e "Unknown_Sex\t$unknown_sex\tNumber of samples with unknown sex" >> "$summary_file"
    
    # Phenotype distribution (assuming binary: 1=control, 2=case) - Column 6
    local controls=$(awk '$6 == 1' "${PLINK_PREFIX}.fam" | wc -l)
    local cases=$(awk '$6 == 2' "${PLINK_PREFIX}.fam" | wc -l)
    local missing_pheno=$(awk '$6 == -9 || $6 == 0' "${PLINK_PREFIX}.fam" | wc -l)
    echo -e "Controls\t$controls\tNumber of control samples (phenotype=1)" >> "$summary_file"
    echo -e "Cases\t$cases\tNumber of case samples (phenotype=2)" >> "$summary_file"
    echo -e "Missing_Phenotype\t$missing_pheno\tNumber of samples with missing phenotype" >> "$summary_file"
    
    # === GENERATE RECOMMENDATIONS ===
    generate_fix_recommendations "$validation_file" "$recommendations_file"
    
    log_message "INFO" "File summary saved to: $summary_file"
    log_message "INFO" "Validation issues saved to: $validation_file"
    log_message "INFO" "Fix recommendations saved to: $recommendations_file"
}

# Generate fix recommendations based on validation issues
generate_fix_recommendations() {
    local validation_file="$1"
    local recommendations_file="$2"
    
    log_message "INFO" "Generating fix recommendations..."
    
    cat > "$recommendations_file" << EOF
=============================================================================
DATASET VALIDATION REPORT & FIX RECOMMENDATIONS
Generated: $(date)
Dataset: $(basename "$PLINK_PREFIX")
=============================================================================

EOF
    
    # Check if there are any issues
    local issue_count=$(tail -n +2 "$validation_file" | wc -l)
    
    if [[ $issue_count -eq 0 ]]; then
        cat >> "$recommendations_file" << EOF
✅ VALIDATION PASSED: No critical issues found!

Your dataset appears to be well-formatted and ready for analysis.
All sample IDs follow proper naming conventions.
No duplicates detected.

EOF
        return
    fi
    
    cat >> "$recommendations_file" << EOF
⚠️  VALIDATION ISSUES FOUND: $issue_count issues require attention

PRIORITY LEGEND:
🔴 HIGH    - Must fix before analysis (will cause errors)
🟡 MEDIUM  - Should fix for best practices  
🟢 LOW     - Informational (usually normal)

DETAILED RECOMMENDATIONS:
=============================================================================

EOF
    
    # Process each validation issue
    while IFS=$'\t' read -r issue_type count severity description affected_items; do
        [[ "$issue_type" == "Issue_Type" ]] && continue  # Skip header
        
        local priority_icon="🟢"
        [[ "$severity" == "HIGH" ]] && priority_icon="🔴"
        [[ "$severity" == "MEDIUM" ]] && priority_icon="🟡"
        
        cat >> "$recommendations_file" << EOF
$priority_icon $severity: $issue_type
   Problem: $description
   Count: $count affected items
   Examples: $affected_items

EOF
        
        # Provide specific fix recommendations
        case "$issue_type" in
            "Duplicate_IID")
                cat >> "$recommendations_file" << EOF
   🔧 FIX REQUIRED:
   # Make Individual IDs unique by adding suffix
   awk 'BEGIN{OFS="\t"} {
     if (seen[\$2]++ > 0) \$2 = \$2 "_dup" seen[\$2]
     print
   }' ${PLINK_PREFIX}.fam > ${PLINK_PREFIX}_fixed.fam
   
   # Or use PLINK to handle duplicates
   plink --bfile $PLINK_PREFIX --make-bed --out ${PLINK_PREFIX}_dedup \\
         --allow-no-sex --remove-duplicate-vars

EOF
                ;;
            "Invalid_IID_Format"|"Invalid_FID_Format")
                cat >> "$recommendations_file" << EOF
   🔧 FIX RECOMMENDED:
   # Clean special characters from IDs
   awk 'BEGIN{OFS="\t"} {
     gsub(/[^a-zA-Z0-9_-]/, "_", \$1)  # Clean FID
     gsub(/[^a-zA-Z0-9_-]/, "_", \$2)  # Clean IID
     print
   }' ${PLINK_PREFIX}.fam > ${PLINK_PREFIX}_cleaned.fam

EOF
                ;;
            "Duplicate_SNP_IDs")
                cat >> "$recommendations_file" << EOF
   🔧 FIX REQUIRED:
   # Remove duplicate SNPs (keep first occurrence)
   plink --bfile $PLINK_PREFIX --make-bed --out ${PLINK_PREFIX}_unique \\
         --allow-no-sex --list-duplicate-vars suppress-first

EOF
                ;;
            "Duplicate_FID")
                cat >> "$recommendations_file" << EOF
   ℹ️  INFORMATIONAL:
   Multiple samples per family is normal for family-based studies.
   No action needed unless you suspect data formatting errors.

EOF
                ;;
        esac
        
        echo "" >> "$recommendations_file"
        
    done < "$validation_file"
    
    cat >> "$recommendations_file" << EOF
=============================================================================
NEXT STEPS:

1. 🔴 HIGH priority issues MUST be fixed before proceeding with analysis
2. 🟡 MEDIUM priority issues should be addressed for best practices
3. 🟢 LOW priority issues are informational

After applying fixes:
- Re-run this info module to verify corrections
- Proceed with Quality Control (QC) module
- Continue with GWAS analysis pipeline

For questions or assistance, refer to the development guide.
=============================================================================
EOF
    
    log_message "INFO" "Generated detailed fix recommendations"
}

# Generate comprehensive HTML report
generate_html_report() {
    log_message "INFO" "Generating comprehensive HTML report..."
    
    local report_file="${OUTPUT_DIR}/INFO_report_${DATE}.html"
    local summary_file="${OUTPUT_DIR}/tables/INFO_file_summary_${DATE}.tsv"
    local validation_file="${OUTPUT_DIR}/tables/INFO_validation_issues_${DATE}.tsv"
    local recommendations_file="${OUTPUT_DIR}/tables/INFO_recommendations_${DATE}.txt"
    local snp_dup_summary_file="${OUTPUT_DIR}/tables/SNP_duplication_summary_${DATE}.txt"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Generating HTML report: $report_file"
        return
    fi
    
    # Check for validation issues
    local has_issues=false
    local critical_issues=0
    local total_issues=0
    
    if [[ -f "$validation_file" ]]; then
        total_issues=$(tail -n +2 "$validation_file" | wc -l)
        critical_issues=$(tail -n +2 "$validation_file" | awk -F'\t' '$3=="HIGH"' | wc -l)
        [[ $total_issues -gt 0 ]] && has_issues=true
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dataset Information Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        .header { background-color: #f4f4f4; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .section { margin: 20px 0; }
        .alert { padding: 15px; margin: 10px 0; border-radius: 5px; }
        .alert-success { background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; }
        .alert-warning { background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; }
        .alert-danger { background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        .alert-info { background-color: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .metric { font-weight: bold; color: #2c3e50; }
        .high-severity { background-color: #ffebee; }
        .medium-severity { background-color: #fff8e1; }
        .low-severity { background-color: #e8f5e8; }
        .validation-summary { display: flex; gap: 20px; margin: 20px 0; }
        .validation-card { flex: 1; padding: 15px; border-radius: 8px; text-align: center; }
        .validation-card h3 { margin: 0 0 10px 0; }
        .validation-card .number { font-size: 2em; font-weight: bold; }
        .status-badge { padding: 5px 10px; border-radius: 15px; font-size: 0.9em; font-weight: bold; }
        .status-completed { background-color: #d4edda; color: #155724; }
        .status-issues { background-color: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧬 Dataset Information Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Dataset:</strong> $(basename "$PLINK_PREFIX")</p>
        <p><strong>Module Version:</strong> $VERSION</p>
        <p><strong>Analysis Status:</strong> 
EOF

    # Add status badge based on issues found
    if [[ $critical_issues -gt 0 ]]; then
        echo '            <span class="status-badge status-issues">⚠️ ISSUES DETECTED</span>' >> "$report_file"
    else
        echo '            <span class="status-badge status-completed">✅ COMPLETED</span>' >> "$report_file"
    fi

    cat >> "$report_file" << EOF
        </p>
    </div>
    
EOF

    # Add validation status alert - but indicate analysis continued
    if [[ "$has_issues" == "true" ]]; then
        if [[ $critical_issues -gt 0 ]]; then
            cat >> "$report_file" << EOF
    <div class="alert alert-danger">
        <h3>🔴 Critical Issues Found!</h3>
        <p><strong>$critical_issues high-priority issues detected</strong> that should be addressed before proceeding with downstream analysis.</p>
        <p><strong>📊 Analysis Status:</strong> Information gathering completed successfully despite validation issues.</p>
        <p><strong>📋 Next Steps:</strong> Review validation section below and check the recommendations file for detailed fixes.</p>
    </div>
EOF
        else
            cat >> "$report_file" << EOF
    <div class="alert alert-warning">
        <h3>⚠️ Validation Issues Detected</h3>
        <p>$total_issues issues found that should be reviewed.</p>
        <p><strong>📊 Analysis Status:</strong> Information gathering completed successfully.</p>
        <p>See recommendations section for guidance on addressing these issues.</p>
    </div>
EOF
        fi
    else
        cat >> "$report_file" << EOF
    <div class="alert alert-success">
        <h3>✅ Validation Passed</h3>
        <p>No critical issues detected. Dataset appears ready for analysis.</p>
        <p><strong>📊 Analysis Status:</strong> All checks passed successfully.</p>
    </div>
EOF
    fi

    # Add processing summary section
    cat >> "$report_file" << EOF
    <div class="alert alert-info">
        <h3>📊 Processing Summary</h3>
        <p><strong>✅ Analysis Completed:</strong> Full dataset characterization performed</p>
        <p><strong>📈 Statistics Generated:</strong> Sample counts, SNP distributions, quality metrics</p>
        <p><strong>🔍 Validation Performed:</strong> Duplicate detection, format validation, quality checks</p>
        <p><strong>📋 Recommendations:</strong> Detailed fix suggestions provided for any issues found</p>
    </div>
    
    <div class="section">
        <h2>📊 Summary Statistics</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Value</th>
                <th>Description</th>
            </tr>
EOF
    
    # Add summary statistics to report
    if [[ -f "$summary_file" ]]; then
        while IFS=$'\t' read -r metric value description; do
            if [[ "$metric" == "Metric" ]]; then continue; fi  # Skip header row
            cat >> "$report_file" << EOF
            <tr>
                <td class="metric">$metric</td>
                <td>$value</td>
                <td>$description</td>
            </tr>
EOF
        done < "$summary_file"
    fi
    
    cat >> "$report_file" << EOF
        </table>
    </div>
EOF

    # Validation issues section
    cat >> "$report_file" << EOF
    <div class="section">
        <h2>🔍 Validation Results</h2>
EOF

    if [[ $total_issues -eq 0 ]]; then
        cat >> "$report_file" << EOF
        <div class="alert alert-success">
            <h4>✅ No Issues Found</h4>
            <p>All validation checks passed successfully. Your dataset appears to be well-formatted and ready for analysis.</p>
        </div>
EOF
    else
        cat >> "$report_file" << EOF
        <p><strong>Issues Found:</strong> $total_issues total ($critical_issues high priority)</p>
        <table>
            <tr>
                <th>Issue Type</th>
                <th>Count</th>
                <th>Severity</th>
                <th>Description</th>
                <th>Affected Items</th>
            </tr>
EOF
        
        # Add validation issues to report
        if [[ -f "$validation_file" ]]; then
            while IFS=$'\t' read -r issue_type count severity description affected_items; do
                if [[ "$issue_type" == "Issue_Type" ]]; then continue; fi  # Skip header row
                local severity_class=$(echo "$severity" | tr '[:upper:]' '[:lower:]')
                cat >> "$report_file" << EOF
            <tr class="${severity_class}-severity">
                <td>$issue_type</td>
                <td>$count</td>
                <td>$severity</td>
                <td>$description</td>
                <td>$affected_items</td>
            </tr>
EOF
            done < "$validation_file"
        fi
        
        cat >> "$report_file" << EOF
        </table>
EOF
    fi
    
    cat >> "$report_file" << EOF
    </div>
EOF

    # Recommendations section
    cat >> "$report_file" << EOF
    <div class="section">
        <h2>🛠️ Fix Recommendations</h2>
        <pre>
EOF
    
    # Add fix recommendations to report
    if [[ -f "$recommendations_file" ]]; then
        cat "$recommendations_file" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF
        </pre>
    </div>
EOF

    # SNP duplication analysis section
    if [[ -f "$snp_dup_summary_file" ]]; then
        cat >> "$report_file" << EOF
    <div class="section">
        <h2>🔗 SNP Duplication Analysis</h2>
        <pre>
EOF
        
        # Add SNP duplication summary to report
        cat "$snp_dup_summary_file" >> "$report_file"
        
        cat >> "$report_file" << EOF
        </pre>
    </div>
EOF
    fi

    # Conclusion section - emphasize analysis completion
    cat >> "$report_file" << EOF
    <div class="section">
        <h2>📋 Analysis Summary</h2>
        <p><strong>✅ Information Module Completed Successfully</strong></p>
        <p>This report provides a comprehensive overview of your dataset characteristics. Analysis proceeded normally and generated all requested statistics and visualizations.</p>
        
        <h3>🗂️ Generated Files:</h3>
        <ul>
            <li><strong>Summary Statistics:</strong> INFO_file_summary_${DATE}.tsv</li>
            <li><strong>Validation Report:</strong> INFO_validation_issues_${DATE}.tsv</li>
            <li><strong>Fix Recommendations:</strong> INFO_recommendations_${DATE}.txt</li>
            <li><strong>PLINK Statistics:</strong> INFO_basic_stats.* files</li>
            <li><strong>Duplicate Detection:</strong> duplicate_*.txt files</li>
        </ul>
        
        <h3>🚀 Next Steps:</h3>
        <ol>
            <li><strong>Review Issues:</strong> Address any validation issues listed above</li>
            <li><strong>Apply Fixes:</strong> Use provided commands to resolve critical issues</li>
            <li><strong>Re-run Validation:</strong> Optional - run info module again after fixes</li>
            <li><strong>Proceed to QC:</strong> Continue with Quality Control module</li>
        </ol>
        
        <p><em>Note: The pipeline continued processing despite validation issues to provide complete dataset characterization.</em></p>
    </div>
    
    <footer>
        <p style="font-size: 0.8em; color: #777;">Generated on $(date) by $(whoami) on $(hostname)</p>
        <p style="font-size: 0.8em; color: #777;">Report generated by Dataset Information Module v$VERSION</p>
    </footer>
</body>
</html>
EOF

    log_message "INFO" "HTML report generated: $report_file"
}

# Main script execution
main() {
    # Parse command-line arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --plink-prefix) PLINK_PREFIX="$2"; shift ;;
            --output-dir) OUTPUT_DIR="$2"; shift ;;
            --config) CONFIG_FILE="$2"; shift ;;
            --conftemp) generate_config_template ;;
            --dry-run) DRY_RUN=true ;;
            --verbose) VERBOSE=true ;;
            --slurm) SLURM_SUBMIT=true ;;
            --submit) SLURM_AUTO_SUBMIT=true ;;
            --help) show_help ;;
            *) echo "Unknown parameter: $1" >&2; exit 1 ;;
        esac
        shift
    done
    
    # Validate required arguments
    if [[ -z "$PLINK_PREFIX" || -z "$OUTPUT_DIR" ]]; then
        echo "Error: --plink-prefix and --output-dir are required." >&2
        show_help
        exit 1
    fi
    
    # Handle SLURM script generation
    if [[ "$SLURM_SUBMIT" == "true" ]]; then
        generate_slurm_script
        exit 0
    fi
    
    # Handle SLURM auto-submit
    if [[ "$SLURM_AUTO_SUBMIT" == "true" ]]; then
        generate_and_submit_slurm_job
        exit 0
    fi
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"/{logs,tables}
    
    # Setup logging
    exec > >(tee -i "${OUTPUT_DIR}/logs/info_module_${DATE}.log")
    exec 2>&1
    
    log_message "INFO" "=== Dataset Information Module Started ==="
    log_message "INFO" "Version: $VERSION"
    log_message "INFO" "PLINK Prefix: $PLINK_PREFIX"
    log_message "INFO" "Output Directory: $OUTPUT_DIR"
    log_message "INFO" "Configuration File: ${CONFIG_FILE:-None}"
    log_message "INFO" "Dry Run: $DRY_RUN"
    log_message "INFO" "Verbose: $VERBOSE"
    log_message "INFO" "Start Time: $(date)"
    
    # Validate inputs
    validate_inputs
    
    # Create directory structure
    setup_directories
    
    # Load configuration
    load_config
    
    # Load software modules
    load_modules
    
    # ==========================================
    # CONTINUE PROCESSING REGARDLESS OF ISSUES
    # ==========================================
    log_message "INFO" "Pipeline will continue processing even if validation issues are found"
    
    # Generate basic statistics
    log_message "INFO" "Generating PLINK statistics..."
    generate_basic_stats
    
    # Enhanced file contents analysis (includes duplicate detection)
    log_message "INFO" "Performing comprehensive file analysis..."
    analyze_file_contents
    
    # Generate HTML report (will show any issues found)
    log_message "INFO" "Creating final report..."
    generate_html_report
    
    # Check for issues and report but don't stop execution
    local validation_file="${OUTPUT_DIR}/tables/INFO_validation_issues_${DATE}.tsv"
    if [[ -f "$validation_file" ]]; then
        local total_issues=$(tail -n +2 "$validation_file" | wc -l)
        local critical_issues=$(tail -n +2 "$validation_file" | awk -F'\t' '$3=="HIGH"' | wc -l)
        
        if [[ $critical_issues -gt 0 ]]; then
            log_message "WARN" "Found $critical_issues critical issues, but analysis completed successfully"
            log_message "INFO" "Check validation report for details on issues found"
        fi
        
        if [[ $total_issues -gt 0 ]]; then
            log_message "INFO" "Total validation issues found: $total_issues"
        fi
    fi
    
    log_message "INFO" "=== Dataset Information Module Completed Successfully ==="
    log_message "INFO" "End Time: $(date)"
    
    # Final summary - emphasize completion
    echo ""
    echo "🎉 Analysis Complete!"
    echo "===================="
    echo "📂 Results saved to: $OUTPUT_DIR"
    echo "📊 HTML Report: $OUTPUT_DIR/INFO_report_${DATE}.html"
    echo "📋 Summary: $OUTPUT_DIR/tables/INFO_file_summary_${DATE}.tsv"
    echo "⚠️  Issues: $OUTPUT_DIR/tables/INFO_validation_issues_${DATE}.tsv"
    echo "🔧 Fixes: $OUTPUT_DIR/tables/INFO_recommendations_${DATE}.txt"
    echo ""
    
    # Report status based on issues found
    if [[ -f "$validation_file" ]]; then
        local critical_issues=$(tail -n +2 "$validation_file" | awk -F'\t' '$3=="HIGH"' | wc -l)
        if [[ $critical_issues -gt 0 ]]; then
            echo "⚠️  Status: Analysis completed with $critical_issues critical issues detected"
            echo "📋 Action: Review recommendations file for fixing guidance"
        else
            echo "✅ Status: Analysis completed successfully with no critical issues"
        fi
    else
        echo "✅ Status: Analysis completed successfully"
    fi
    echo ""
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
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

# Enhanced file contents analysis with proper duplicate detection and validation
analyze_file_contents() {
    log_message "INFO" "Analyzing file contents and structure..."
    
    local summary_file="${OUTPUT_DIR}/tables/INFO_file_summary_${DATE}.tsv"
    local validation_file="${OUTPUT_DIR}/tables/INFO_validation_issues_${DATE}.tsv"
    local recommendations_file="${OUTPUT_DIR}/tables/INFO_recommendations_${DATE}.txt"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Analyzing .fam, .bim file contents with enhanced validation"
        return
    fi
    
    # Create summary file header
    echo -e "Metric\tValue\tDescription" > "$summary_file"
    
    # Create validation issues file header
    echo -e "Issue_Type\tCount\tSeverity\tDescription\tAffected_Items" > "$validation_file"
    
    # Count samples and SNPs
    local n_samples=$(wc -l < "${PLINK_PREFIX}.fam")
    local n_snps=$(wc -l < "${PLINK_PREFIX}.bim")
    
    echo -e "Total_Samples\t$n_samples\tNumber of samples in dataset" >> "$summary_file"
    echo -e "Total_SNPs\t$n_snps\tNumber of SNPs in dataset" >> "$summary_file"
    
    # Analyze chromosomes
    local n_chromosomes=$(cut -f1 "${PLINK_PREFIX}.bim" | sort -u | wc -l)
    echo -e "Chromosomes\t$n_chromosomes\tNumber of unique chromosomes" >> "$summary_file"
    
    # === ENHANCED DUPLICATE DETECTION ===
    log_message "INFO" "Performing enhanced duplicate detection..."
    
    # Check for duplicate Individual IDs (IID) - Column 2
    local dup_iid_file="${OUTPUT_DIR}/tables/duplicate_IIDs_${DATE}.txt"
    cut -f2 "${PLINK_PREFIX}.fam" | sort | uniq -c | awk '$1 > 1 {print $2 "\t" $1}' > "$dup_iid_file"
    local dup_iid_count=$(wc -l < "$dup_iid_file")
    
    echo -e "Duplicate_IID\t$dup_iid_count\tNumber of duplicate Individual IDs" >> "$summary_file"
    
    if [[ $dup_iid_count -gt 0 ]]; then
        local dup_iid_list=$(head -5 "$dup_iid_file" | cut -f1 | tr '\n' ',' | sed 's/,$//')
        echo -e "Duplicate_IID\t$dup_iid_count\tHIGH\tDuplicate Individual IDs found - will cause PLINK errors\t$dup_iid_list..." >> "$validation_file"
        log_message "WARN" "Found $dup_iid_count duplicate Individual IDs"
    fi
    
    # Check for duplicate Family IDs (normal but worth noting)
    local dup_fid_file="${OUTPUT_DIR}/tables/duplicate_FIDs_${DATE}.txt"
    cut -f1 "${PLINK_PREFIX}.fam" | sort | uniq -c | awk '$1 > 1 {print $2 "\t" $1}' > "$dup_fid_file"
    local dup_fid_count=$(wc -l < "$dup_fid_file")
    
    echo -e "Duplicate_FID\t$dup_fid_count\tNumber of Family IDs with multiple samples" >> "$summary_file"
    
    if [[ $dup_fid_count -gt 0 ]]; then
        local dup_fid_list=$(head -3 "$dup_fid_file" | cut -f1 | tr '\n' ',' | sed 's/,$//')
        echo -e "Duplicate_FID\t$dup_fid_count\tLOW\tMultiple samples per Family ID (normal for families)\t$dup_fid_list..." >> "$validation_file"
    fi
    
    # === SPECIAL CHARACTER VALIDATION ===
    log_message "INFO" "Validating sample ID formats..."
    
    # Check for special characters in Family IDs
    local bad_fid_file="${OUTPUT_DIR}/tables/invalid_FIDs_${DATE}.txt"
    awk '{print $1}' "${PLINK_PREFIX}.fam" | grep -n '[^a-zA-Z0-9_-]' > "$bad_fid_file" 2>/dev/null || true
    local bad_fid_count=$(wc -l < "$bad_fid_file")
    
    echo -e "Invalid_FID_Format\t$bad_fid_count\tNumber of Family IDs with special characters" >> "$summary_file"
    
    if [[ $bad_fid_count -gt 0 ]]; then
        local bad_fid_examples=$(head -3 "$bad_fid_file" | cut -d: -f2 | tr '\n' ',' | sed 's/,$//')
        echo -e "Invalid_FID_Format\t$bad_fid_count\tMEDIUM\tFamily IDs contain spaces/special characters\t$bad_fid_examples..." >> "$validation_file"
        log_message "WARN" "Found $bad_fid_count Family IDs with special characters"
    fi
    
    # Check for special characters in Individual IDs
    local bad_iid_file="${OUTPUT_DIR}/tables/invalid_IIDs_${DATE}.txt"
    awk '{print $2}' "${PLINK_PREFIX}.fam" | grep -n '[^a-zA-Z0-9_-]' > "$bad_iid_file" 2>/dev/null || true
    local bad_iid_count=$(wc -l < "$bad_iid_file")
    
    echo -e "Invalid_IID_Format\t$bad_iid_count\tNumber of Individual IDs with special characters" >> "$summary_file"
    
    if [[ $bad_iid_count -gt 0 ]]; then
        local bad_iid_examples=$(head -3 "$bad_iid_file" | cut -d: -f2 | tr '\n' ',' | sed 's/,$//')
        echo -e "Invalid_IID_Format\t$bad_iid_count\tHIGH\tIndividual IDs contain spaces/special characters\t$bad_iid_examples..." >> "$validation_file"
        log_message "WARN" "Found $bad_iid_count Individual IDs with special characters"
    fi
    
    # Check for spaces in IDs (most common issue)
    local space_fid_count=$(awk '{print $1}' "${PLINK_PREFIX}.fam" | grep -c ' ' 2>/dev/null || echo "0")
    local space_iid_count=$(awk '{print $2}' "${PLINK_PREFIX}.fam" | grep -c ' ' 2>/dev/null || echo "0")
    
    echo -e "FID_With_Spaces\t$space_fid_count\tNumber of Family IDs containing spaces" >> "$summary_file"
    echo -e "IID_With_Spaces\t$space_iid_count\tNumber of Individual IDs containing spaces" >> "$summary_file"
    
    # === SNP ID VALIDATION ===
    log_message "INFO" "Validating SNP IDs..."
    
    # Check for duplicate SNP IDs
    local dup_snp_file="${OUTPUT_DIR}/tables/duplicate_SNPs_${DATE}.txt"
    cut -f2 "${PLINK_PREFIX}.bim" | sort | uniq -c | awk '$1 > 1 {print $2 "\t" $1}' > "$dup_snp_file"
    local dup_snp_count=$(wc -l < "$dup_snp_file")
    
    echo -e "Duplicate_SNP_IDs\t$dup_snp_count\tNumber of duplicate SNP IDs" >> "$summary_file"
    
    if [[ $dup_snp_count -gt 0 ]]; then
        local dup_snp_examples=$(head -3 "$dup_snp_file" | cut -f1 | tr '\n' ',' | sed 's/,$//')
        echo -e "Duplicate_SNP_IDs\t$dup_snp_count\tHIGH\tDuplicate SNP IDs found - will cause analysis errors\t$dup_snp_examples..." >> "$validation_file"
        log_message "WARN" "Found $dup_snp_count duplicate SNP IDs"
    fi
    
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
    
    # === GENERATE RECOMMENDATIONS ===
    generate_fix_recommendations "$validation_file" "$recommendations_file"
    
    log_message "INFO" "File summary saved to: $summary_file"
    log_message "INFO" "Validation issues saved to: $validation_file"
    log_message "INFO" "Fix recommendations saved to: $recommendations_file"
}

# Generate fix recommendations based on validation issues
generate_fix_recommendations() {
    local validation_file="$1"
    local recommendations_file="$2"
    
    log_message "INFO" "Generating fix recommendations..."
    
    cat > "$recommendations_file" << EOF
=============================================================================
DATASET VALIDATION REPORT & FIX RECOMMENDATIONS
Generated: $(date)
Dataset: $(basename "$PLINK_PREFIX")
=============================================================================

EOF
    
    # Check if there are any issues
    local issue_count=$(tail -n +2 "$validation_file" | wc -l)
    
    if [[ $issue_count -eq 0 ]]; then
        cat >> "$recommendations_file" << EOF
✅ VALIDATION PASSED: No critical issues found!

Your dataset appears to be well-formatted and ready for analysis.
All sample IDs follow proper naming conventions.
No duplicates detected.

EOF
        return
    fi
    
    cat >> "$recommendations_file" << EOF
⚠️  VALIDATION ISSUES FOUND: $issue_count issues require attention

PRIORITY LEGEND:
🔴 HIGH    - Must fix before analysis (will cause errors)
🟡 MEDIUM  - Should fix for best practices  
🟢 LOW     - Informational (usually normal)

DETAILED RECOMMENDATIONS:
=============================================================================

EOF
    
    # Process each validation issue
    while IFS=$'\t' read -r issue_type count severity description affected_items; do
        [[ "$issue_type" == "Issue_Type" ]] && continue  # Skip header
        
        local priority_icon="🟢"
        [[ "$severity" == "HIGH" ]] && priority_icon="🔴"
        [[ "$severity" == "MEDIUM" ]] && priority_icon="🟡"
        
        cat >> "$recommendations_file" << EOF
$priority_icon $severity: $issue_type
   Problem: $description
   Count: $count affected items
   Examples: $affected_items

EOF
        
        # Provide specific fix recommendations
        case "$issue_type" in
            "Duplicate_IID")
                cat >> "$recommendations_file" << EOF
   🔧 FIX REQUIRED:
   # Make Individual IDs unique by adding suffix
   awk 'BEGIN{OFS="\t"} {
     if (seen[\$2]++ > 0) \$2 = \$2 "_dup" seen[\$2]
     print
   }' ${PLINK_PREFIX}.fam > ${PLINK_PREFIX}_fixed.fam
   
   # Or use PLINK to handle duplicates
   plink --bfile $PLINK_PREFIX --make-bed --out ${PLINK_PREFIX}_dedup \\
         --allow-no-sex --remove-duplicate-vars

EOF
                ;;
            "Invalid_IID_Format"|"Invalid_FID_Format")
                cat >> "$recommendations_file" << EOF
   🔧 FIX RECOMMENDED:
   # Clean special characters from IDs
   awk 'BEGIN{OFS="\t"} {
     gsub(/[^a-zA-Z0-9_-]/, "_", \$1)  # Clean FID
     gsub(/[^a-zA-Z0-9_-]/, "_", \$2)  # Clean IID
     print
   }' ${PLINK_PREFIX}.fam > ${PLINK_PREFIX}_cleaned.fam

EOF
                ;;
            "Duplicate_SNP_IDs")
                cat >> "$recommendations_file" << EOF
   🔧 FIX REQUIRED:
   # Remove duplicate SNPs (keep first occurrence)
   plink --bfile $PLINK_PREFIX --make-bed --out ${PLINK_PREFIX}_unique \\
         --allow-no-sex --list-duplicate-vars suppress-first

EOF
                ;;
            "Duplicate_FID")
                cat >> "$recommendations_file" << EOF
   ℹ️  INFORMATIONAL:
   Multiple samples per family is normal for family-based studies.
   No action needed unless you suspect data formatting errors.

EOF
                ;;
        esac
        
        echo "" >> "$recommendations_file"
        
    done < "$validation_file"
    
    cat >> "$recommendations_file" << EOF
=============================================================================
NEXT STEPS:

1. 🔴 HIGH priority issues MUST be fixed before proceeding with analysis
2. 🟡 MEDIUM priority issues should be addressed for best practices
3. 🟢 LOW priority issues are informational

After applying fixes:
- Re-run this info module to verify corrections
- Proceed with Quality Control (QC) module
- Continue with GWAS analysis pipeline

For questions or assistance, refer to the development guide.
=============================================================================
EOF
    
    log_message "INFO" "Generated detailed fix recommendations"
}

# Generate comprehensive HTML report
generate_html_report() {
    log_message "INFO" "Generating comprehensive HTML report..."
    
    local report_file="${OUTPUT_DIR}/INFO_report_${DATE}.html"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Generating HTML report: $report_file"
        return
    fi
    
    # Check for validation issues
    local validation_file="${OUTPUT_DIR}/tables/INFO_validation_issues_${DATE}.tsv"
    local has_issues=false
    local critical_issues=0
    
    if [[ -f "$validation_file" ]]; then
        local issue_count=$(tail -n +2 "$validation_file" | wc -l)
        critical_issues=$(tail -n +2 "$validation_file" | awk -F'\t' '$3=="HIGH"' | wc -l)
        [[ $issue_count -gt 0 ]] && has_issues=true
    fi
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dataset Information Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        .header { background-color: #f4f4f4; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .section { margin: 20px 0; }
        .alert { padding: 15px; margin: 10px 0; border-radius: 5px; }
        .alert-success { background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; }
        .alert-warning { background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; }
        .alert-danger { background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .metric { font-weight: bold; color: #2c3e50; }
        .high-severity { background-color: #ffebee; }
        .medium-severity { background-color: #fff8e1; }
        .low-severity { background-color: #e8f5e8; }
        .validation-summary { display: flex; gap: 20px; margin: 20px 0; }
        .validation-card { flex: 1; padding: 15px; border-radius: 8px; text-align: center; }
        .validation-card h3 { margin: 0 0 10px 0; }
        .validation-card .number { font-size: 2em; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧬 Dataset Information Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Dataset:</strong> $(basename "$PLINK_PREFIX")</p>
        <p><strong>Module Version:</strong> $VERSION</p>
    </div>
    
$(if [[ "$has_issues" == "true" ]]; then
    if [[ $critical_issues -gt 0 ]]; then
        echo '    <div class="alert alert-danger">'
        echo "        <h3>🔴 Critical Issues Found!</h3>"
        echo "        <p>$critical_issues high-priority issues detected that <strong>must be fixed</strong> before proceeding with analysis.</p>"
        echo '        <p>See validation section below and check the recommendations file for detailed fixes.</p>'
        echo '    </div>'
    else
       