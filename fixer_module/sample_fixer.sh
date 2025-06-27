#!/bin/bash
# =============================================================================
# MODULE NAME: Sample ID Fixer
# PURPOSE: Fix sample ID issues in PLINK .fam files including duplicates and invalid characters
# INPUTS: PLINK .fam file
# OUTPUTS: Fixed .fam file and detailed sample fixing report
# USAGE: ./sample_fixer.sh --fam input.fam --out output_prefix [OPTIONS]
# AUTHOR: Alsamman M. Alsamman
# =============================================================================

set -euo pipefail # Exit on any error, undefined variable, or pipe failure

# Default parameters
FIX_DUPLICATES=true
FIX_INVALID_CHARS=true
ALLOWED_CHARS="A-Za-z0-9_-"
DUPLICATE_SUFFIX="_dup"

# Function to display usage
usage() {
    cat << EOF
Sample ID Fixer - Fix sample ID issues in PLINK .fam files

USAGE:
    $0 --fam <input.fam> --out <output_prefix> [OPTIONS]

REQUIRED ARGUMENTS:
    --fam <file>         Input PLINK .fam file
    --out <prefix>       Output file prefix

OPTIONAL ARGUMENTS:
    --fix-duplicates <bool>  Fix duplicate sample IDs (default: true)
    --fix-invalid <bool>     Fix invalid characters in sample names (default: true)
    --allowed-chars <str>    Regex pattern for allowed characters (default: "A-Za-z0-9_-")
    --duplicate-suffix <str> Suffix for duplicate resolution (default: "_dup")
    --help                   Show this help message

EOF
}

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to fix invalid characters in sample names using sed
fix_invalid_characters() {
    local input_fam="$1"
    local temp_fam="$2"
    local report_file="$3"
    
    log_message "Fixing invalid characters in sample names..."
    
    local invalid_pattern="[^${ALLOWED_CHARS}]"
    
    awk -v report_file="$report_file" -v invalid_pattern="$invalid_pattern" '
    {
        original_fid = $1
        original_iid = $2
        
        # Replace invalid characters in FID and IID with underscores
        gsub(invalid_pattern, "_", $1)
        gsub(invalid_pattern, "_", $2)
        
        if (original_fid != $1 || original_iid != $2) {
            report_line = sprintf("INVALID_CHARS\t%s\t%s\t%s\t%s\tFixed invalid characters",
                                  original_fid, original_iid, $1, $2);
            print report_line >> report_file;
            fflush(report_file);
        }
        
        print $0
    }
    ' "$input_fam" > "$temp_fam"
    
    if [[ $(wc -l < "$report_file") -gt 1 ]]; then
        log_message "Invalid characters fixed and logged."
    else
        log_message "No invalid characters found."
    fi
}


# Function to fix duplicate sample IDs using a robust AWK script
# This version checks for duplicates based on IID (Column 2) ONLY.
fix_duplicate_samples() {
    local input_fam="$1"
    local output_fam="$2"
    local report_file="$3"

    log_message "Fixing duplicate sample IDs (based on IID - Column 2)..."

    local temp_report="${report_file}.dup.tmp"
    
    # AWK script does all the work:
    # 1. Reads the input .fam file.
    # 2. Uses an array `counts` to track IIDs (Column 2).
    # 3. If an IID is seen more than once, it modifies the IID ($2).
    # 4. It prints the (possibly modified) line to the new .fam file (stdout).
    # 5. It prints a report line to a temporary report file (stderr).
    awk -v suffix="$DUPLICATE_SUFFIX" '
    {
        # The key is now ONLY the Individual ID (IID), column 2.
        key = $2
        
        # Increment the counter for this key
        counts[key]++
        
        # If this is the second or later time we see this key, it is a duplicate
        if (counts[key] > 1) {
            original_iid = $2
            # Create the new IID, e.g., C12_dup1, C12_dup2
            $2 = $2 suffix (counts[key] - 1)
            
            # Print a report line to stderr for logging
            # The original FID ($1) is preserved.
            printf "DUPLICATE\t%s\t%s\t%s\t%s\tResolved duplicate IID\n", $1, original_iid, $1, $2 > "/dev/stderr"
        }
        
        # Print the current line (original or modified) to stdout
        print $0
    }
    ' "$input_fam" > "$output_fam" 2>> "$temp_report"

    # Append the temporary duplicate report to the main report file
    if [ -s "$temp_report" ]; then
        log_message "Duplicate IIDs found and fixed."
        cat "$temp_report" >> "$report_file"
    else
        log_message "No duplicate IIDs found."
    fi

    rm -f "$temp_report"
}

# Main function
main() {
    log_message "Starting Sample ID Fixer..."
    log_message "Input: $INPUT_FAM"
    log_message "Output: $OUTPUT_PREFIX"
    
    if [[ ! -f "$INPUT_FAM" ]]; then
        echo "ERROR: Input .fam file not found: $INPUT_FAM" >&2
        exit 1
    fi
    
    local output_dir
    output_dir=$(dirname "$OUTPUT_PREFIX")
    mkdir -p "$output_dir/tables" "$output_dir/logs"
    
    local final_fam="${OUTPUT_PREFIX}.fam"
    local report_file="${output_dir}/tables/FIXER_sample_changes.tsv"
    
    echo -e "Change_Type\tOriginal_FID\tOriginal_IID\tNew_FID\tNew_IID\tDescription" > "$report_file"
    
    local current_fam="$INPUT_FAM"
    local temp_fam_invalid="${OUTPUT_PREFIX}.fam.invalid.tmp"
    local temp_fam_final="${OUTPUT_PREFIX}.fam.final.tmp"

    if [[ "$FIX_INVALID_CHARS" == "true" ]]; then
        fix_invalid_characters "$current_fam" "$temp_fam_invalid" "$report_file"
        current_fam="$temp_fam_invalid"
    fi
    
    if [[ "$FIX_DUPLICATES" == "true" ]]; then
        fix_duplicate_samples "$current_fam" "$temp_fam_final" "$report_file"
        mv "$temp_fam_final" "$final_fam"
    else
        cp "$current_fam" "$final_fam"
    fi
    
    rm -f "$temp_fam_invalid" "$temp_fam_final"

    local changes_made
    changes_made=$(($(wc -l < "$report_file") - 1))
    
    if [[ $changes_made -lt 0 ]]; then changes_made=0; fi

    log_message "Sample fixing completed!"
    log_message "Total changes made: $changes_made"
    log_message "Output .fam file: $final_fam"
    log_message "Change report: $report_file"
}

# --- Argument Parsing ---
INPUT_FAM=""
OUTPUT_PREFIX=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --fam) INPUT_FAM="$2"; shift 2 ;;
        --out) OUTPUT_PREFIX="$2"; shift 2 ;;
        --fix-duplicates) FIX_DUPLICATES="$2"; shift 2 ;;
        --fix-invalid) FIX_INVALID_CHARS="$2"; shift 2 ;;
        --allowed-chars) ALLOWED_CHARS="$2"; shift 2 ;;
        --duplicate-suffix) DUPLICATE_SUFFIX="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) echo "ERROR: Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$INPUT_FAM" || -z "$OUTPUT_PREFIX" ]]; then
    echo "ERROR: Missing required arguments --fam and --out" >&2
    usage
    exit 1
fi

main