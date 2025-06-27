#!/bin/bash
# =============================================================================
# MODULE NAME: PLINK Data Fixer Module
# PURPOSE: Fix common issues in PLINK binary files including sample ID problems and SNP duplications
# INPUTS: PLINK binary files (.bed, .bim, .fam) and optional configuration file
# OUTPUTS: Fixed PLINK files, detailed reports, and logs in organized directory structure
# USAGE: ./fixer_module.sh --bfile input_data --out output_prefix [--config config.yaml] [--conftemp] [--submit]
# AUTHOR: Alsamman M. Alsamman
# =============================================================================

set -euo pipefail  # Exit on any error, undefined variable, or pipe failure

# Script directory for finding helper scripts
# This robustly finds the real path of the script, even if it's a symlink or being run by a scheduler like SLURM.
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

# Additional check for SLURM environment - if helper scripts don't exist in SCRIPT_DIR,
# try to find them in the original location
if [[ ! -f "$SCRIPT_DIR/sample_fixer.sh" ]]; then
    # Check SLURM_SUBMIT_DIR if available
    if [[ -n "${SLURM_SUBMIT_DIR:-}" ]] && [[ -f "$SLURM_SUBMIT_DIR/sample_fixer.sh" ]]; then
        SCRIPT_DIR="$SLURM_SUBMIT_DIR"
    # Check if we're in a subdirectory and look for fixer_module directory
    elif [[ -f "$(dirname "$PWD")/fixer_module/sample_fixer.sh" ]]; then
        SCRIPT_DIR="$(dirname "$PWD")/fixer_module"
    # Check current directory
    elif [[ -f "$PWD/sample_fixer.sh" ]]; then
        SCRIPT_DIR="$PWD"
    # Check relative to current script location
    elif [[ -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null)/sample_fixer.sh" ]]; then
        SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" 2>/dev/null)"
    fi
fi

# Default parameters
DEFAULT_OUTPUT_DIR="results/fixer"
DEFAULT_CONFIG=""
GENERATE_CONFIG_TEMPLATE=false
SUBMIT_JOB=false
USE_SLURM=true  # Default to using SLURM for PLINK operations
VERBOSE=false

# Global variables for configuration
FIX_DUPLICATE_SAMPLES=true
FIX_INVALID_CHARS=true
ALLOWED_CHARS="A-Za-z0-9_-"
DUPLICATE_SUFFIX="_dup"
FIX_DUPLICATE_RSID=true
FIX_DUPLICATE_CHRPOS=true
KEEP_FIRST_DUPLICATE=true
GENERATE_REPORTS=true
ARCHIVE_ORIGINALS=true
CREATE_PLOTS=true

# Global variables for module loading from config
PLINK_MODULE=""
PYTHON_MODULE=""

# Function to display usage
usage() {
    cat << EOF
PLINK Data Fixer Module - Fix common PLINK file issues

USAGE:
    $0 --bfile <input_prefix> --out <output_prefix> [OPTIONS]

REQUIRED ARGUMENTS:
    --bfile <prefix>     Input PLINK binary file prefix (without .bed/.bim/.fam extension)
    --out <prefix>       Output file prefix for fixed files

OPTIONAL ARGUMENTS:
    --config <file>      YAML configuration file with fixing parameters
    --conftemp           Generate configuration template and exit
    --outdir <dir>       Output directory for reports (default: creates subdir near output)
    --submit             Generate and submit SLURM job script
    --use-slurm          Always use SLURM for PLINK operations (recommended for large datasets)
    --no-slurm           Use direct PLINK execution (may fail on large datasets)
    --verbose            Enable verbose output
    --help               Show this help message

EXAMPLES:
    # Basic usage (uses SLURM for PLINK by default)
    $0 --bfile mydata --out mydata_fixed

    # With configuration file (will automatically load modules specified in the file)
    $0 --bfile mydata --out mydata_fixed --config fixer_config.yaml

    # Force direct PLINK execution (not recommended for large datasets)
    $0 --bfile mydata --out mydata_fixed --no-slurm

    # Generate configuration template
    $0 --conftemp

    # Submit entire job as SLURM job
    $0 --bfile mydata --out mydata_fixed --submit

EOF
}

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to generate configuration template
generate_config_template() {
    # ... This function remains unchanged ...
    # (Content omitted for brevity, but it's identical to your original script)
    local template_file="fixer_config_template.yaml"
    cat << 'EOF' > "$template_file"
# PLINK Data Fixer Module Configuration Template
# =============================================================================
# This configuration file controls the behavior of the PLINK Data Fixer Module
# Copy this file and modify the parameters as needed for your analysis
#
# IMPORTANT: When SNPs are removed due to duplicate chr:pos, the module uses
# PLINK to ensure .bed, .bim, and .fam files remain synchronized. Make sure
# PLINK is available in your PATH for proper binary genotype file handling.
# =============================================================================

# Sample ID Fixing Parameters
sample_fixing:
  fix_duplicates: true           # Fix duplicated sample IDs
  fix_invalid_chars: true        # Fix invalid characters in sample names
  allowed_chars: "A-Za-z0-9_-"   # Allowed characters in sample names (regex pattern)
  duplicate_suffix: "_dup"       # Suffix for duplicate sample resolution
  
# SNP Fixing Parameters  
snp_fixing:
  fix_duplicate_rsid: true       # Replace duplicate rsIDs with '.'
  fix_duplicate_chrpos: true     # Remove SNPs with duplicate chr:pos
  keep_first_duplicate: true     # Keep first occurrence of duplicate chr:pos (if false, removes all)
  
# Output Options
output:
  generate_reports: true         # Generate detailed fixing reports
  archive_originals: true        # Archive original files in archive/ subdirectory
  create_plots: true            # Create visualization plots (requires Python with matplotlib)

# Processing Options
processing:
  check_file_integrity: true    # Verify file integrity before processing
  backup_intermediate: false    # Keep intermediate files for debugging
  verbose_logging: true         # Enable detailed logging output

# HPC/SLURM Configuration
hpc:
  auto_submit: false            # Automatically submit SLURM job when --submit flag is used
  job_name: "fixer_module"      # SLURM job name
  cpus: 4                       # Number of CPUs to request
  memory: "32G"                 # Memory to request
  time_limit: "02:00:00"        # Time limit for job
  email: "alsammana@omrf.org"   # Email for job notifications
  
# Module Loading (for HPC environments)
modules:
  plink: "plink/1.90b6.21"      # Example: PLINK module to load
  python: "python/3.8"          # Example: Python module to load
  
# Advanced Options
advanced:
  chunk_size: 10000            # Process files in chunks (for very large datasets)
  parallel_processing: false   # Enable parallel processing (experimental)
  temp_directory: "/tmp"       # Temporary directory for intermediate files
EOF
    log_message "Configuration template generated: $template_file"
    exit 0
}

# Function to parse configuration file with improved error handling
parse_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then echo "ERROR: Configuration file not found: $config_file"; exit 1; fi
    if [[ ! -r "$config_file" ]]; then echo "ERROR: Configuration file not readable: $config_file"; exit 1; fi
    
    log_message "Loading configuration from: $config_file"
    
    # Debug: Show what we're looking for
    log_message "Parsing YAML configuration (looking for indented keys)..."
    
    # Debug: Show what keys are found
    local sample_keys
    sample_keys=$(grep -E "^\s+fix_duplicates:" "$config_file" 2>/dev/null || echo "NOT_FOUND")
    log_message "  Sample duplicate key found: '$sample_keys'"
    
    local snp_keys
    snp_keys=$(grep -E "^\s+fix_duplicate_rsid:" "$config_file" 2>/dev/null || echo "NOT_FOUND")  
    log_message "  SNP duplicate key found: '$snp_keys'"
    
    local chrpos_keys
    chrpos_keys=$(grep -E "^\s+fix_duplicate_chrpos:" "$config_file" 2>/dev/null || echo "NOT_FOUND")  
    log_message "  SNP chrpos key found: '$chrpos_keys'"
    
    # Parse YAML using simple grep/sed - handle nested structure and comments properly
    FIX_DUPLICATE_SAMPLES=$(grep -E "^\s+fix_duplicates:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    FIX_INVALID_CHARS=$(grep -E "^\s+fix_invalid_chars:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    ALLOWED_CHARS=$(grep -E "^\s+allowed_chars:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' -e 's/["'\'']//g' | tr -d ' \n' || echo "A-Za-z0-9_-")
    DUPLICATE_SUFFIX=$(grep -E "^\s+duplicate_suffix:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' -e 's/["'\'']//g' | tr -d ' \n' || echo "_dup")
    FIX_DUPLICATE_RSID=$(grep -E "^\s+fix_duplicate_rsid:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    FIX_DUPLICATE_CHRPOS=$(grep -E "^\s+fix_duplicate_chrpos:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    KEEP_FIRST_DUPLICATE=$(grep -E "^\s+keep_first_duplicate:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    GENERATE_REPORTS=$(grep -E "^\s+generate_reports:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    ARCHIVE_ORIGINALS=$(grep -E "^\s+archive_originals:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    CREATE_PLOTS=$(grep -E "^\s+create_plots:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' | tr -d ' \n' || echo "true")
    
    # NEW: Parse module configuration
    log_message "Parsing module configuration from YAML..."
    # In fixer_module.sh -> parse_config()
    PLINK_MODULE=$(grep -E "^\s*plink:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' -e 's/["'\'']//g' | tr -d ' ' || echo "")
    PYTHON_MODULE=$(grep -E "^\s*python:" "$config_file" 2>/dev/null | sed -e 's/#.*//' -e 's/.*:\s*//' -e 's/["'\'']//g' | tr -d ' ' || echo "")

    if [[ -n "$PLINK_MODULE" ]]; then
        log_message "  Found PLINK module in config: $PLINK_MODULE"
    fi
    if [[ -n "$PYTHON_MODULE" ]]; then
        log_message "  Found Python module in config: $PYTHON_MODULE"
    fi
    
    log_message "Configuration loaded successfully"
    
    # Debug: Log parsed values
    log_message "Parsed configuration values:"
    log_message "  FIX_DUPLICATE_SAMPLES: $FIX_DUPLICATE_SAMPLES"
    log_message "  FIX_INVALID_CHARS: $FIX_INVALID_CHARS"
    log_message "  FIX_DUPLICATE_RSID: $FIX_DUPLICATE_RSID"
    log_message "  FIX_DUPLICATE_CHRPOS: $FIX_DUPLICATE_CHRPOS"
    log_message "  KEEP_FIRST_DUPLICATE: $KEEP_FIRST_DUPLICATE"
}

# NEW: Function to load required modules based on configuration
load_modules() {
    log_message "Attempting to load configured modules..."
    local modules_loaded=false

    # Check if the 'module' command itself exists
    if ! command -v module >/dev/null 2>&1; then
        log_message "WARNING: 'module' command not found. Cannot load modules automatically."
        log_message "         Please ensure required software (PLINK, Python) is in your PATH."
        return 1
    fi

    # Attempt to load the PLINK module if specified
    if [[ -n "$PLINK_MODULE" ]]; then
        log_message "  > Loading PLINK module: $PLINK_MODULE"
        if module load "$PLINK_MODULE"; then
            log_message "    Successfully loaded $PLINK_MODULE."
            modules_loaded=true
        else
            log_message "    WARNING: Failed to load module '$PLINK_MODULE'. The script will proceed but may fail if plink is not in the PATH."
        fi
    fi

    # Attempt to load the Python module if specified
    if [[ -n "$PYTHON_MODULE" ]]; then
        log_message "  > Loading Python module: $PYTHON_MODULE"
        if module load "$PYTHON_MODULE"; then
            log_message "    Successfully loaded $PYTHON_MODULE."
        else
            log_message "    WARNING: Failed to load module '$PYTHON_MODULE'. Report/plot generation might fail."
        fi
    fi

    if [[ "$modules_loaded" == "false" && -n "$DEFAULT_CONFIG" ]]; then
         log_message "NOTE: No modules were specified in the config file. Assuming software is already in PATH."
    fi
}

# Function to validate input files with comprehensive checks
validate_inputs() {
    # ... This function remains unchanged ...
    # (Content omitted for brevity, but it's identical to your original script)
    log_message "Validating input files..."
    local bfile_prefix="$1"
    if [[ ! -f "${bfile_prefix}.bed" || ! -f "${bfile_prefix}.bim" || ! -f "${bfile_prefix}.fam" ]]; then
        echo "ERROR: Missing one or more PLINK files for prefix: $bfile_prefix" >&2
        exit 1
    fi
    log_message "Input validation: PASSED"
    local samples=$(wc -l < "${bfile_prefix}.fam")
    local snps=$(wc -l < "${bfile_prefix}.bim")
    log_message "Input data: ${samples} samples, ${snps} SNPs"
}

# Function to setup output directory structure
setup_output_directory() {
    # ... This function remains unchanged ...
    # (Content omitted for brevity, but it's identical to your original script)
    local output_dir="$1"
    log_message "Setting up output directory: $output_dir"
    mkdir -p "$output_dir"/{archive,logs,plots,tables}
    if [[ "$ARCHIVE_ORIGINALS" == "true" ]]; then
        log_message "Archiving original files..."
        cp "${INPUT_BFILE}.bed" "${INPUT_BFILE}.bim" "${INPUT_BFILE}.fam" "$output_dir/archive/"
    fi
}

# Function to check if PLINK is available
check_plink_availability() {
    if command -v plink >/dev/null 2>&1; then
        local plink_version
        plink_version=$(plink --version 2>/dev/null | head -1 || echo "PLINK 1.x")
        log_message "PLINK found: $plink_version"
        return 0
    elif command -v plink2 >/dev/null 2>&1; then
        local plink2_version
        plink2_version=$(plink2 --version 2>/dev/null | head -1 || echo "PLINK 2.x")
        log_message "PLINK2 found: $plink2_version"
        return 0
    else
        log_message "CRITICAL WARNING: PLINK not found in PATH. SNP removal will cause file desynchronization!"
        return 1
    fi
}

# Function to detect available system resources for memory optimization
detect_system_resources() {
    log_message "Detecting system resources..."
    
    # Check if running under SLURM
    if [[ -n "${SLURM_MEM_PER_NODE:-}" ]]; then
        local slurm_mem_mb=$((SLURM_MEM_PER_NODE))
        log_message "SLURM allocation detected: ${slurm_mem_mb}MB memory allocated"
        
        # Reserve some memory for system and other processes
        local available_mem=$((slurm_mem_mb * 80 / 100))  # Use 80% of allocated memory
        log_message "Will use approximately ${available_mem}MB for PLINK processing"
        
    elif [[ -n "${SLURM_MEM_PER_CPU:-}" ]] && [[ -n "${SLURM_CPUS_PER_TASK:-}" ]]; then
        local slurm_mem_mb=$((SLURM_MEM_PER_CPU * SLURM_CPUS_PER_TASK))
        log_message "SLURM allocation detected: ${slurm_mem_mb}MB memory allocated (${SLURM_MEM_PER_CPU}MB/CPU × ${SLURM_CPUS_PER_TASK} CPUs)"
        
        local available_mem=$((slurm_mem_mb * 80 / 100))
        log_message "Will use approximately ${available_mem}MB for PLINK processing"
        
    # Check available system memory if free command is available
    elif command -v free >/dev/null 2>&1; then
        local available_mem
        available_mem=$(free -m | awk '/^Mem:/ {print $7}')
        if [[ $available_mem -gt 0 ]]; then
            log_message "Available system memory: ${available_mem}MB"
            if [[ $available_mem -lt 8000 ]]; then
                log_message "WARNING: Low available memory detected. PLINK processing may be slow or fail."
                log_message "Consider requesting more memory or using a machine with more RAM."
            fi
        fi
    else
        log_message "Cannot detect system memory. Will use conservative PLINK memory settings."
    fi
    
    # Check available disk space in temp directory
    local temp_space
    if command -v df >/dev/null 2>&1; then
        temp_space=$(df -BG "${OUTPUT_PREFIX%/*}" 2>/dev/null | awk 'NR==2 {gsub(/G/, "", $4); print $4}' || echo "unknown")
        if [[ "$temp_space" != "unknown" ]] && [[ $temp_space -lt 50 ]]; then
            log_message "WARNING: Low disk space detected (${temp_space}GB available). Large dataset processing may fail."
        fi
    fi
}

# Function to generate SLURM script
generate_slurm_script() {
    # ... This function remains unchanged ...
    # (Content omitted for brevity, but it's identical to your original script)
    # It correctly uses the module variables if they were parsed from the config.
    local script_name="fixer_module_job.sh"
    local current_dir=$(pwd)
    cat << EOF > "$script_name"
#!/bin/bash
#SBATCH --job-name=fixer_module
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --mail-user=alsammana@omrf.org
#SBATCH --mail-type=ALL
#SBATCH --output=fixer_module_%j.out
#SBATCH --error=fixer_module_%j.err

# Load required modules from config or defaults
module load ${PLINK_MODULE:-plink/1.90b6.21}
module load ${PYTHON_MODULE:-python/3.8}

# Change to working directory
cd "$current_dir"

# Run the fixer module
bash "$SCRIPT_DIR/fixer_module.sh" "$@"
EOF
    log_message "SLURM script generated: $script_name"
    if [[ "$SUBMIT_JOB" == "true" ]]; then
        log_message "Submitting job to SLURM..."
        sbatch "$script_name"
    else
        log_message "To submit job, run: sbatch $script_name"
    fi
}

# Function to detect system resources for memory optimization
detect_system_resources() {
    log_message "Detecting system resources for optimization..."

    # Detect total system memory
    if command -v free >/dev/null 2>&1; then
        local total_mem_kb
        total_mem_kb=$(free -k | awk '/^Mem:/{print $2}')
        TOTAL_MEMORY_GB=$((total_mem_kb / 1024 / 1024))
        log_message "Total system memory: ${TOTAL_MEMORY_GB} GB"
    else
        log_message "WARNING: Unable to detect total memory (free command not found). Defaulting to 32 GB."
        TOTAL_MEMORY_GB=32
    fi

    # Detect number of available CPUs
    if command -v nproc >/dev/null 2>&1; then
        TOTAL_CPUS=$(nproc)
        log_message "Total available CPUs: $TOTAL_CPUS"
    else
        log_message "WARNING: Unable to detect number of CPUs (nproc command not found). Defaulting to 4 CPUs."
        TOTAL_CPUS=4
    fi

    # Set default memory and CPU values for SLURM if not already set
    if [[ -z "${SLURM_CPUS:-}" ]]; then
        SLURM_CPUS=$TOTAL_CPUS
    fi
    if [[ -z "${SLURM_MEMORY:-}" ]]; then
        SLURM_MEMORY="${TOTAL_MEMORY_GB}G"
    fi

    log_message "SLURM resource requests: ${SLURM_CPUS} CPUs, ${SLURM_MEMORY} memory"
}

# Function to calculate optimal PLINK memory settings
calculate_plink_memory() {
    local num_snps="$1"
    local default_memory=8000  # 8GB default
    
    # Base memory calculation on SLURM allocation if available
    if [[ -n "${SLURM_MEM_PER_NODE:-}" ]]; then
        local slurm_mem_mb=$((SLURM_MEM_PER_NODE))
        local max_plink_memory=$((slurm_mem_mb * 70 / 100))  # Use 70% of allocated memory
        
    elif [[ -n "${SLURM_MEM_PER_CPU:-}" ]] && [[ -n "${SLURM_CPUS_PER_TASK:-}" ]]; then
        local slurm_mem_mb=$((SLURM_MEM_PER_CPU * SLURM_CPUS_PER_TASK))
        local max_plink_memory=$((slurm_mem_mb * 70 / 100))
        
    elif command -v free >/dev/null 2>&1; then
        local available_mem
        available_mem=$(free -m | awk '/^Mem:/ {print $7}')
        local max_plink_memory=$((available_mem * 60 / 100))  # Use 60% of available memory
    else
        local max_plink_memory=$default_memory
    fi
    
    # Adjust based on dataset size
    local recommended_memory
    if [[ $num_snps -gt 15000000 ]]; then
        recommended_memory=16000  # 16GB for very large datasets
    elif [[ $num_snps -gt 10000000 ]]; then
        recommended_memory=12000  # 12GB for large datasets
    elif [[ $num_snps -gt 5000000 ]]; then
        recommended_memory=8000   # 8GB for medium datasets
    else
        recommended_memory=4000   # 4GB for smaller datasets
    fi
    
    # Use the smaller of recommended and maximum available
    local final_memory
    if [[ $max_plink_memory -lt $recommended_memory ]]; then
        final_memory=$max_plink_memory
        log_message "Memory constraint: using ${final_memory}MB (limited by available memory)"
    else
        final_memory=$recommended_memory
        log_message "Memory setting: using ${final_memory}MB for dataset with $num_snps SNPs"
    fi
    
    # Ensure minimum memory
    if [[ $final_memory -lt 2000 ]]; then
        final_memory=2000
        log_message "Warning: Very low memory detected, using minimum 2GB"
    fi
    
    echo $final_memory
}

# Function to submit PLINK job via SLURM with proper resource allocation
submit_plink_job() {
    local temp_dir="$1"
    local output_prefix="$2"
    local num_snps="$3"
    local plink_cmd="$4"
    
    log_message "Preparing SLURM job for PLINK filtering..."
    
    # Calculate resources based on dataset size
    local memory_gb
    local cpus
    local time_limit
    
    if [[ $num_snps -gt 15000000 ]]; then
        memory_gb=64
        cpus=8
        time_limit="04:00:00"
    elif [[ $num_snps -gt 10000000 ]]; then
        memory_gb=32
        cpus=4
        time_limit="02:00:00"
    elif [[ $num_snps -gt 5000000 ]]; then
        memory_gb=16
        cpus=2
        time_limit="01:00:00"
    else
        memory_gb=8
        cpus=1
        time_limit="30:00"
    fi
    
    local job_name="plink_filter_$(basename "$output_prefix")"
    local plink_job_script="${output_prefix}_plink_job.sh"
    local current_dir=$(pwd)
    
    log_message "Creating SLURM job script: $plink_job_script"
    log_message "Resources: ${memory_gb}GB memory, ${cpus} CPUs, ${time_limit} time limit"
    
    cat << EOF > "$plink_job_script"
#!/bin/bash
#SBATCH --job-name=${job_name}
#SBATCH --cpus-per-task=${cpus}
#SBATCH --mem=${memory_gb}G
#SBATCH --time=${time_limit}
#SBATCH --output=${output_prefix}_plink_%j.out
#SBATCH --error=${output_prefix}_plink_%j.err
#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=\${USER}@omrf.org

# Load required modules
module load ${PLINK_MODULE:-plink/1.90b6.21}

# Change to working directory
cd "$current_dir"

# Log job start
echo "============================================================================="
echo "PLINK Filtering Job Started: \$(date)"
echo "Job ID: \$SLURM_JOB_ID"
echo "Memory allocated: ${memory_gb}GB"
echo "CPUs allocated: ${cpus}"
echo "Dataset size: ${num_snps} SNPs"
echo "============================================================================="

# Run PLINK filtering with optimal settings
echo "Running PLINK filtering..."
if $plink_cmd --bfile "$temp_dir/working" \\
              --extract "$temp_dir/snps_to_keep.txt" \\
              --make-bed \\
              --out "$output_prefix" \\
              --allow-extra-chr \\
              --allow-no-sex \\
              --memory $((memory_gb * 1000 * 80 / 100)) \\
              --threads ${cpus}; then
    
    echo "PLINK filtering completed successfully."
    echo "Output files generated at: $output_prefix"
    
    # Verify output files
    if [[ -f "${output_prefix}.bed" && -f "${output_prefix}.bim" && -f "${output_prefix}.fam" ]]; then
        final_snps=\$(wc -l < "${output_prefix}.bim")
        final_samples=\$(wc -l < "${output_prefix}.fam")
        echo "Final dataset: \$final_samples samples, \$final_snps SNPs"
        
        # Create success marker
        echo "PLINK_SUCCESS" > "${output_prefix}.plink_status"
    else
        echo "ERROR: Output files not created properly"
        echo "PLINK_FAILED" > "${output_prefix}.plink_status"
        exit 1
    fi
else
    echo "ERROR: PLINK filtering failed"
    echo "PLINK_FAILED" > "${output_prefix}.plink_status"
    exit 1
fi

echo "============================================================================="
echo "PLINK Filtering Job Completed: \$(date)"
echo "============================================================================="
EOF

    # Submit the job
    log_message "Submitting PLINK job to SLURM..."
    local job_id
    job_id=$(sbatch "$plink_job_script" | awk '{print $4}')
    
    if [[ -n "$job_id" ]]; then
        log_message "PLINK job submitted successfully. Job ID: $job_id"
        log_message "Waiting for PLINK job to complete..."
        
        # Wait for job to complete
        local status_file="${output_prefix}.plink_status"
        local max_wait_time=14400  # 4 hours maximum wait
        local wait_time=0
        local check_interval=30    # Check every 30 seconds
        
        while [[ $wait_time -lt $max_wait_time ]]; do
            if [[ -f "$status_file" ]]; then
                local status
                status=$(cat "$status_file")
                if [[ "$status" == "PLINK_SUCCESS" ]]; then
                    log_message "PLINK job completed successfully!"
                    rm -f "$status_file" "$plink_job_script"
                    return 0
                elif [[ "$status" == "PLINK_FAILED" ]]; then
                    echo "ERROR: PLINK job failed. Check ${output_prefix}_plink_${job_id}.err for details" >&2
                    rm -f "$status_file"
                    return 1
                fi
            fi
            
            # Check if job is still running
            if ! squeue -j "$job_id" &>/dev/null; then
                # Job finished but no status file - something went wrong
                echo "ERROR: PLINK job finished unexpectedly. Check ${output_prefix}_plink_${job_id}.err for details" >&2
                return 1
            fi
            
            sleep $check_interval
            wait_time=$((wait_time + check_interval))
            
            # Print periodic status updates
            if (( wait_time % 300 == 0 )); then  # Every 5 minutes
                log_message "Still waiting for PLINK job (${wait_time}s elapsed)..."
            fi
        done
        
        echo "ERROR: PLINK job timed out after $((max_wait_time/3600)) hours" >&2
        scancel "$job_id" 2>/dev/null
        return 1
    else
        echo "ERROR: Failed to submit PLINK job" >&2
        return 1
    fi
}

# Main function with improved error handling and workflow
main() {
    local log_file="${OUTPUT_DIR}/logs/fixer_module_$(date '+%Y%m%d_%H%M%S').log"
    
    mkdir -p "$(dirname "$log_file")"
    exec &> >(tee -a "$log_file")
    
    echo "============================================================================="
    echo "PLINK Data Fixer Module"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "============================================================================="
    
    # Validate helper scripts are available
    log_message "Script directory: $SCRIPT_DIR"
    if [[ ! -f "$SCRIPT_DIR/sample_fixer.sh" ]]; then
        echo "ERROR: Helper script not found: $SCRIPT_DIR/sample_fixer.sh" >&2
        echo "Current working directory: $(pwd)" >&2
        echo "Available files in SCRIPT_DIR:" >&2
        ls -la "$SCRIPT_DIR" 2>/dev/null || echo "Directory not accessible: $SCRIPT_DIR" >&2
        exit 1
    fi
    if [[ ! -f "$SCRIPT_DIR/snp_fixer.sh" ]]; then
        echo "ERROR: Helper script not found: $SCRIPT_DIR/snp_fixer.sh" >&2
        exit 1
    fi
    log_message "Helper scripts validated successfully"
    
    # Validate inputs
    validate_inputs "$INPUT_BFILE"
    
    # MODIFIED: Load modules from config file *before* checking for PLINK
    if [[ -n "$DEFAULT_CONFIG" ]]; then
        load_modules
    fi

    # Setup output directory
    setup_output_directory "$OUTPUT_DIR"
    
    # Check PLINK availability (this will now succeed if the module was loaded)
    check_plink_availability
    local plink_available=$?
    
    log_message "Parameters used:"
    log_message "  Input file: $INPUT_BFILE"
    log_message "  Output prefix: $OUTPUT_PREFIX"
    
    # Detect system resources for memory optimization
    detect_system_resources
    
    # Create temporary working directory
    local temp_dir
    temp_dir=$(mktemp -d "${OUTPUT_PREFIX}_temp_XXXXXX")
    trap "rm -rf '$temp_dir'" EXIT
    log_message "Created temporary directory: $temp_dir"
    
    # Initialize working files
    cp "${INPUT_BFILE}.bed" "$temp_dir/working.bed"
    cp "${INPUT_BFILE}.bim" "$temp_dir/working.bim"
    cp "${INPUT_BFILE}.fam" "$temp_dir/working.fam"
    
    local changes_made=false
    
    # Debug: Show current configuration values before processing
    log_message "Configuration values being used:"
    log_message "  FIX_DUPLICATE_SAMPLES: '$FIX_DUPLICATE_SAMPLES'"
    log_message "  FIX_INVALID_CHARS: '$FIX_INVALID_CHARS'"
    log_message "  FIX_DUPLICATE_RSID: '$FIX_DUPLICATE_RSID'"
    log_message "  FIX_DUPLICATE_CHRPOS: '$FIX_DUPLICATE_CHRPOS'"
    
    # Process sample fixes
    if [[ "$FIX_DUPLICATE_SAMPLES" == "true" || "$FIX_INVALID_CHARS" == "true" ]]; then
        log_message "Running sample fixer..."
        bash "$SCRIPT_DIR/sample_fixer.sh" \
            --fam "$temp_dir/working.fam" \
            --out "$temp_dir/sample_fixed" \
            --fix-duplicates "$FIX_DUPLICATE_SAMPLES" \
            --fix-invalid "$FIX_INVALID_CHARS"
        
        # Overwrite working .fam file with the fixed version
        mv "$temp_dir/sample_fixed.fam" "$temp_dir/working.fam"
        # Move reports
        mv "$temp_dir/tables/"* "$OUTPUT_DIR/tables/" 2>/dev/null || true
        rmdir "$temp_dir/tables"
        changes_made=true
    fi
    
    # Process SNP fixes
    log_message "Checking SNP fixing conditions:"
    log_message "  FIX_DUPLICATE_RSID == 'true': $([[ "$FIX_DUPLICATE_RSID" == "true" ]] && echo "YES" || echo "NO")"
    log_message "  FIX_DUPLICATE_CHRPOS == 'true': $([[ "$FIX_DUPLICATE_CHRPOS" == "true" ]] && echo "YES" || echo "NO")"
    
    if [[ "$FIX_DUPLICATE_RSID" == "true" || "$FIX_DUPLICATE_CHRPOS" == "true" ]]; then
        log_message "Running SNP fixer..."
        bash "$SCRIPT_DIR/snp_fixer.sh" \
            --bim "$temp_dir/working.bim" \
            --out "$temp_dir/snp_fixed" \
            --fix-rsid "$FIX_DUPLICATE_RSID" \
            --fix-chrpos "$FIX_DUPLICATE_CHRPOS" \
            --keep-first "$KEEP_FIRST_DUPLICATE"
        
        local original_snps fixed_snps
        original_snps=$(wc -l < "$temp_dir/working.bim")
        fixed_snps=$(wc -l < "$temp_dir/snp_fixed.bim")
        
        # Move SNP reports now
        mv "$temp_dir/tables/"* "$OUTPUT_DIR/tables/" 2>/dev/null || true
        rmdir "$temp_dir/tables" 2>/dev/null || true
        
        if [[ $original_snps -ne $fixed_snps ]]; then
            log_message "SNPs changed: $original_snps -> $fixed_snps (removed: $((original_snps - fixed_snps)))"
            
            if [[ $plink_available -eq 0 ]]; then
                # Get the correct PLINK command
                local plink_cmd="plink"
                command -v plink >/dev/null || plink_cmd="plink2"

                # Use the SNP IDs from the newly created .bim to filter
                awk '{print $2}' "$temp_dir/snp_fixed.bim" > "$temp_dir/snps_to_keep.txt"
                
                local num_snps_to_keep
                num_snps_to_keep=$(wc -l < "$temp_dir/snps_to_keep.txt")
                log_message "Filtering dataset to keep $num_snps_to_keep SNPs..."
                
                if [[ "$USE_SLURM" == "true" ]]; then
                    log_message "Using SLURM to submit PLINK job with optimal resource allocation..."
                    # Submit PLINK job via SLURM with proper resource allocation
                    if submit_plink_job "$temp_dir" "${OUTPUT_PREFIX}" "$num_snps_to_keep" "$plink_cmd"; then
                        log_message "PLINK filtering completed successfully via SLURM job"
                    else
                        echo "ERROR: PLINK SLURM job failed" >&2
                        exit 1
                    fi
                else
                    log_message "Using direct PLINK execution..."
                    # Calculate optimal memory settings based on system resources and dataset size
                    local optimal_memory
                    optimal_memory=$(calculate_plink_memory "$num_snps_to_keep")
                    local memory_args="--memory $optimal_memory"
                    
                    # Use PLINK with memory optimization and better error handling
                    log_message "Running PLINK filtering (this may take 10-20 minutes for large datasets)..."
                    if timeout 3600 $plink_cmd --bfile "$temp_dir/working" \
                                  --extract "$temp_dir/snps_to_keep.txt" \
                                  --make-bed \
                                  --out "${OUTPUT_PREFIX}" \
                                  --allow-extra-chr \
                                  --allow-no-sex \
                                  $memory_args \
                                  --threads 1; then
                        
                        log_message "PLINK filtering completed successfully. Output files generated at ${OUTPUT_PREFIX}"
                    else
                        local exit_code=$?
                        if [[ $exit_code -eq 124 ]]; then
                            echo "ERROR: PLINK filtering timed out after 1 hour" >&2
                        else
                            echo "ERROR: PLINK filtering failed (exit code: $exit_code)" >&2
                        fi
                        
                        # Fallback: try with even more aggressive memory settings
                        local fallback_memory=$((optimal_memory / 2))
                        if [[ $fallback_memory -lt 2000 ]]; then
                            fallback_memory=2000
                        fi
                        log_message "Attempting fallback with minimal memory usage (${fallback_memory}MB)..."
                        if $plink_cmd --bfile "$temp_dir/working" \
                                      --extract "$temp_dir/snps_to_keep.txt" \
                                      --make-bed \
                                      --out "${OUTPUT_PREFIX}" \
                                      --allow-extra-chr \
                                      --allow-no-sex \
                                      --memory $fallback_memory \
                                      --threads 1 \
                                      --silent; then
                            log_message "PLINK filtering completed with fallback settings."
                        else
                            echo "ERROR: PLINK filtering failed even with minimal memory settings" >&2
                            echo "Consider using --use-slurm option for better resource management" >&2
                            exit 1
                        fi
                    fi
                fi
            else
                echo "ERROR: PLINK not found, but SNPs were removed. Cannot synchronize files. Aborting." >&2
                exit 1
            fi
        else
            log_message "No SNPs removed, copying files directly."
            cp "$temp_dir/working.bed" "${OUTPUT_PREFIX}.bed"
            cp "$temp_dir/snp_fixed.bim" "${OUTPUT_PREFIX}.bim" # Use the potentially rsID-fixed bim
            cp "$temp_dir/working.fam" "${OUTPUT_PREFIX}.fam"
        fi
        changes_made=true
    else
        log_message "SNP fixing conditions not met - skipping SNP processing"
        log_message "No SNP fixing requested, copying files directly."
        cp "$temp_dir/working.bed" "${OUTPUT_PREFIX}.bed"
        cp "$temp_dir/working.bim" "${OUTPUT_PREFIX}.bim"
        cp "$temp_dir/working.fam" "${OUTPUT_PREFIX}.fam"
    fi
    
    # Final verification
    log_message "Final data at ${OUTPUT_PREFIX}: $(wc -l < "${OUTPUT_PREFIX}.fam") samples, $(wc -l < "${OUTPUT_PREFIX}.bim") SNPs"
    
    echo "============================================================================="
    echo "PLINK Data Fixer Module completed successfully"
    echo "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Fixed PLINK files: ${OUTPUT_PREFIX}.{bed,bim,fam}"
    echo "Reports available in: $OUTPUT_DIR/tables"
    echo "============================================================================="
}

# --- Main execution block ---

# Parse command line arguments
INPUT_BFILE=""
OUTPUT_PREFIX=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --bfile) INPUT_BFILE="$2"; shift 2 ;;
        --out) OUTPUT_PREFIX="$2"; shift 2 ;;
        --outdir) DEFAULT_OUTPUT_DIR="$2"; shift 2 ;;
        --config) DEFAULT_CONFIG="$2"; shift 2 ;;
        --conftemp) GENERATE_CONFIG_TEMPLATE=true; shift ;;
        --submit) SUBMIT_JOB=true; shift ;;
        --use-slurm) USE_SLURM=true; shift ;;
        --no-slurm) USE_SLURM=false; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --help) usage; exit 0 ;;
        *) echo "ERROR: Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [[ "$GENERATE_CONFIG_TEMPLATE" == "true" ]]; then
    generate_config_template
fi

if [[ -z "$INPUT_BFILE" || -z "$OUTPUT_PREFIX" ]]; then
    echo "ERROR: Missing required arguments --bfile and --out"; usage; exit 1
fi

OUTPUT_PREFIX_DIR=$(dirname "$OUTPUT_PREFIX")
if [[ "$DEFAULT_OUTPUT_DIR" == "results/fixer" ]]; then
    OUTPUT_DIR="${OUTPUT_PREFIX_DIR}/fixer_results"
else
    OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
fi

if [[ -n "$DEFAULT_CONFIG" ]]; then
    parse_config "$DEFAULT_CONFIG"
fi

if [[ "$SUBMIT_JOB" == "true" ]]; then
    # Pass all original arguments except for --submit itself
    args=("$@")
    # This rebuilds the original command line to pass to the slurm script
    all_args=(--bfile "$INPUT_BFILE" --out "$OUTPUT_PREFIX")
    [[ -n "$DEFAULT_CONFIG" ]] && all_args+=(--config "$DEFAULT_CONFIG")
    [[ -n "$VERBOSE" ]] && all_args+=(--verbose)
    generate_slurm_script "${all_args[@]}"
    exit 0
fi

main