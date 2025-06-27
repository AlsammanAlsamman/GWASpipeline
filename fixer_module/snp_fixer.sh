#!/bin/bash
# =============================================================================
# MODULE NAME: SNP Fixer
# PURPOSE: Fix SNP issues in PLINK .bim files including duplicate rsIDs and chr:pos
# INPUTS: PLINK .bim file
# OUTPUTS: Fixed .bim file and detailed SNP fixing report
# USAGE: ./snp_fixer.sh --bim input.bim --out output_prefix [OPTIONS]
# AUTHOR: Alsamman M. Alsamman
# =============================================================================

set -euo pipefail # Exit on any error, undefined variable, or pipe failure

# Default parameters
FIX_DUPLICATE_RSID=true
FIX_DUPLICATE_CHRPOS=true
KEEP_FIRST_DUPLICATE=true

# Function to display usage
usage() {
    cat << EOF
SNP Fixer - Fix SNP issues in PLINK .bim files

USAGE:
    $0 --bim <input.bim> --out <output_prefix> [OPTIONS]

REQUIRED ARGUMENTS:
    --bim <file>         Input PLINK .bim file
    --out <prefix>       Output file prefix

OPTIONAL ARGUMENTS:
    --fix-rsid <bool>      Fix duplicate rsIDs by replacing with '.' (default: true)
    --fix-chrpos <bool>    Remove SNPs with duplicate chr:pos (default: true)
    --keep-first <bool>    Keep first occurrence of duplicate chr:pos (default: true)
    --help                 Show this help message

NOTES:
    - This script is optimized for performance and low memory usage on large files.
    - Duplicate rsIDs: Subsequent occurrences of a duplicate rsID are replaced with '.'
    - Duplicate chr:pos: If --keep-first is true, only the first occurrence is kept.
      If --keep-first is false, ALL occurrences of a duplicated chr:pos are removed.

EOF
}

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check file size and provide memory usage estimates
check_file_size_and_memory() {
    local input_file="$1"
    local num_lines
    num_lines=$(wc -l < "$input_file")
    
    log_message "Input file contains $num_lines SNPs"
    
    # Estimate memory usage (rough approximation)
    # For very large files (>10M SNPs), provide warnings and recommendations
    if [[ $num_lines -gt 10000000 ]]; then
        log_message "WARNING: Large dataset detected (>10M SNPs). Memory-optimized processing enabled."
        log_message "Estimated processing time: 10-30 minutes depending on system resources."
        
        # Check available memory if possible
        if command -v free >/dev/null 2>&1; then
            local available_mem
            available_mem=$(free -m | awk '/^Mem:/ {print $7}')
            if [[ $available_mem -lt 4000 ]]; then
                log_message "WARNING: Low available memory detected ($available_mem MB). Processing may be slow."
            fi
        fi
    elif [[ $num_lines -gt 5000000 ]]; then
        log_message "Medium-large dataset detected (>5M SNPs). Using optimized processing."
    fi
}

# Function to fix duplicate rsIDs using a memory-efficient sort-based approach
fix_duplicate_rsids() {
    local input_bim="$1"
    local temp_bim="$2"
    local report_file="$3"
    
    log_message "Fixing duplicate rsIDs using memory-efficient approach..."
    local temp_report="${report_file}.rsid.tmp"
    
    # Step 1: Find duplicate rsIDs efficiently using sort and uniq
    local duplicate_rsids_file="${temp_bim}.duprsids.tmp"
    
    log_message "Extracting and sorting rsIDs to identify duplicates..."
    # Extract rsIDs (excluding "."), sort, and find duplicates
    awk '$2 != "." {print $2}' "$input_bim" | sort | uniq -d > "$duplicate_rsids_file"
    
    local num_dup_rsids
    num_dup_rsids=$(wc -l < "$duplicate_rsids_file")
    
    if [[ $num_dup_rsids -eq 0 ]]; then
        log_message "No duplicate rsIDs found."
        cp "$input_bim" "$temp_bim"
        rm -f "$duplicate_rsids_file"
        return
    fi
    
    log_message "Found $num_dup_rsids unique rsIDs with duplicates. Processing main file..."
    
    # Step 2: Process the .bim file, replacing duplicate rsIDs with "."
    awk '
    BEGIN {
        # Read the list of duplicate rsIDs into an associative array
        while ((getline rsid < "'"$duplicate_rsids_file"'") > 0) {
            is_duplicate[rsid] = 1
        }
        close("'"$duplicate_rsids_file"'");
    }
    {
        # Skip processing if rsID is already "." (PLINKs missing ID format)
        if ($2 == ".") {
            print $0
            next
        }
        
        # Check if this rsID is in our list of duplicates
        if ($2 in is_duplicate) {
            # This is a duplicate. Log the change and modify the rsID to "."
            original_rsid = $2
            $2 = "."
            printf "DUPLICATE_RSID\t%s\t%s\t%s\t%s\tDuplicate rsID replaced with \x27.\x27\n", $1, $4, original_rsid, $2 > "/dev/stderr"
        }
        
        # Print the (possibly modified) line to stdout
        print $0
    }
    ' "$input_bim" > "$temp_bim" 2>> "$temp_report"

    if [ -s "$temp_report" ]; then
        log_message "Duplicate rsIDs found and fixed."
        cat "$temp_report" >> "$report_file"
    else
        log_message "No duplicate rsIDs found."
    fi
    
    # Clean up temporary files
    rm -f "$temp_report" "$duplicate_rsids_file"
}

# Function to fix duplicate chr:pos using a memory-efficient sort/uniq/awk approach
fix_duplicate_chrpos() {
    local input_bim="$1"
    local output_bim="$2"
    local report_file="$3"

    log_message "Identifying SNPs with duplicate chromosome and position..."

    # This is a memory-efficient way to handle huge files.
    # 1. awk extracts the chr:pos key from every line.
    # 2. sort puts identical keys next to each other.
    # 3. uniq -d finds only the keys that are duplicated.
    # The result is a small file containing only the chr:pos keys that need to be removed/handled.
    local duplicate_keys_file="${output_bim}.dupkeys.tmp"
    awk '{print $1":"$4}' "$input_bim" | sort | uniq -d > "$duplicate_keys_file"
    
    local num_dup_keys
    num_dup_keys=$(wc -l < "$duplicate_keys_file")
    
    if [[ $num_dup_keys -eq 0 ]]; then
        log_message "No duplicate chr:pos found. Copying file directly."
        cp "$input_bim" "$output_bim"
        rm -f "$duplicate_keys_file"
        return
    fi
    
    log_message "Found $num_dup_keys chr:pos keys with duplicates. Processing..."
    local temp_report="${report_file}.chrpos.tmp"

    # Now, process the main .bim file using awk.
    # The `BEGIN` block reads the small list of bad keys into an array.
    # The main block then processes the .bim file line-by-line, checking against the bad keys.
    awk -v keep_first="$KEEP_FIRST_DUPLICATE" '
    BEGIN {
        # Read the file of duplicate keys into an associative array for fast lookups.
        while ((getline key < "'"$duplicate_keys_file"'") > 0) {
            is_duplicate[key] = 1
        }
        close("'"$duplicate_keys_file"'");
    }
    {
        key = $1":"$4
        
        # Check if the current SNP has a chr:pos that we identified as a duplicate
        if (key in is_duplicate) {
            if (keep_first == "true") {
                # We want to keep the first occurrence of a duplicated key
                if (!(key in processed)) {
                    # First time seeing this duplicated key, so print it and log it
                    print $0
                    printf "DUPLICATE_CHRPOS_KEPT\t%s\t%s\t%s\t%s\tFirst occurrence of duplicate chr:pos kept\n", $1, $4, $2, $2 > "/dev/stderr"
                    processed[key] = 1 # Mark as processed so we dont print it again
                } else {
                    # Subsequent occurrence, so remove it and log
                    printf "DUPLICATE_CHRPOS_REMOVED\t%s\t%s\t%s\t-\tSubsequent occurrence of duplicate chr:pos removed\n", $1, $4, $2 > "/dev/stderr"
                }
            } else {
                # We want to remove ALL occurrences of duplicated keys
                printf "DUPLICATE_CHRPOS_REMOVED\t%s\t%s\t%s\t-\tAll occurrences of duplicate chr:pos removed\n", $1, $4, $2 > "/dev/stderr"
            }
        } else {
            # This SNP is unique, so keep it
            print $0
        }
    }
    ' "$input_bim" > "$output_bim" 2>> "$temp_report"

    # Append the temporary chr:pos report to the main report file
    if [ -s "$temp_report" ]; then
        cat "$temp_report" >> "$report_file"
    fi

    # Clean up temporary files
    rm -f "$duplicate_keys_file" "$temp_report"
}

# Main function
main() {
    log_message "Starting SNP Fixer..."
    log_message "Input: $INPUT_BIM"
    log_message "Output: $OUTPUT_PREFIX"
    
    # Validate input file
    if [[ ! -f "$INPUT_BIM" ]]; then
        echo "ERROR: Input .bim file not found: $INPUT_BIM" >&2
        exit 1
    fi
    
    # Check file size and provide memory usage estimates
    check_file_size_and_memory "$INPUT_BIM"
    
    # Setup output files
    local output_dir
    output_dir=$(dirname "$OUTPUT_PREFIX")
    mkdir -p "$output_dir/tables" "$output_dir/logs"
    
    local final_bim="${OUTPUT_PREFIX}.bim"
    local report_file="${output_dir}/tables/FIXER_snp_changes.tsv"
    
    # Initialize report file with header
    echo -e "Change_Type\tChromosome\tPosition\tOriginal_rsID\tNew_rsID\tDescription" > "$report_file"

    local current_bim="$INPUT_BIM"
    local temp_bim_rsid="${OUTPUT_PREFIX}.bim.rsid.tmp"

    # --- Step 1: Fix Duplicate rsIDs ---
    if [[ "$FIX_DUPLICATE_RSID" == "true" ]]; then
        fix_duplicate_rsids "$current_bim" "$temp_bim_rsid" "$report_file"
        current_bim="$temp_bim_rsid"
    fi
    
    # --- Step 2: Fix Duplicate chr:pos ---
    # This function will read from the current state (either original or rsID-fixed)
    # and write to the final .bim file location.
    if [[ "$FIX_DUPLICATE_CHRPOS" == "true" ]]; then
        fix_duplicate_chrpos "$current_bim" "$final_bim" "$report_file"
    else
        # If not fixing chr:pos, just move the current state to the final location
        cp "$current_bim" "$final_bim"
    fi
    
    # Clean up intermediate files
    rm -f "$temp_bim_rsid"

    # --- Step 3: Generate Summary Statistics ---
    local changes_made
    changes_made=$(($(wc -l < "$report_file") - 1))
    local original_snps
    original_snps=$(wc -l < "$INPUT_BIM")
    local fixed_snps
    fixed_snps=$(wc -l < "$final_bim")

    if [[ $changes_made -lt 0 ]]; then changes_made=0; fi

    log_message "SNP fixing completed!"
    log_message "Original SNPs: $original_snps"
    log_message "SNPs after fixing: $fixed_snps (Removed: $((original_snps - fixed_snps)))"
    log_message "Total changes logged: $changes_made"
    log_message "Output .bim file: $final_bim"
    log_message "Change report: $report_file"
}


# --- Argument Parsing ---
INPUT_BIM=""
OUTPUT_PREFIX=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --bim) INPUT_BIM="$2"; shift 2 ;;
        --out) OUTPUT_PREFIX="$2"; shift 2 ;;
        --fix-rsid) FIX_DUPLICATE_RSID="$2"; shift 2 ;;
        --fix-chrpos) FIX_DUPLICATE_CHRPOS="$2"; shift 2 ;;
        --keep-first) KEEP_FIRST_DUPLICATE="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) echo "ERROR: Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# Check required arguments
if [[ -z "$INPUT_BIM" || -z "$OUTPUT_PREFIX" ]]; then
    echo "ERROR: Missing required arguments --bim and --out" >&2
    usage
    exit 1
fi

# Run main function
main