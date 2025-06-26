### 
I'm developing a modular genomic data analysis pipeline for PLINK-formatted datasets. The pipeline will consist of independent stages, each organized in separate folders according to analysis type (e.g., QC, GWAS, harmonization, etc.).

### Key Notes:

* **Each script will be written and tested individually.**
* **You should not write the full pipeline at once.**
* **Start with the `info` module.**

---

### Overall Pipeline Structure:

1. **Information Module (First Step) - ✅ ENHANCED & FIXED**

   * Summarizes key dataset stats:

     * Number of SNPs and samples
     * **Enhanced duplicate detection:**
       * **FIXED: Proper detection of duplicate Individual IDs (IID)** - Critical issue
       * **FIXED: Corrected space-delimited parsing for .fam files**
       * Family ID (FID) duplication tracking - Normal for families
       * Duplicate SNP ID detection with chr:pos analysis
     * **Sample ID validation:**
       * Special character detection in FID/IID (spaces, symbols)
       * Format validation (alphanumeric + underscore/hyphen only)
       * Detailed fix recommendations for formatting issues
     * Chromosomal distribution
     * Sample counts by FID and sex
     * Phenotype distribution (binary only, since we work on Lupus)
   * **Enhanced outputs:**
     * Validation issues report with severity levels (HIGH/MEDIUM/LOW)
     * Detailed fix recommendations with executable commands
     * Issue-specific temporary files for troubleshooting
     * **DEBUG: Added detailed logging for duplicate detection verification**
   * Input: PLINK files
   * Output: Tables, summary plots, validation reports, and comprehensive HTML report

2. **Quality Control (QC) Module**

   * Checks and fixes genome build
   * Ensures unique sample names (fix FID/IID if needed)
   * Harmonizes with GRCh37 (I have a script for this)
   * Removes related samples (IBD > threshold)
   * Identifies population outliers via PCA
   * Removes multi-allelic SNPs

3. **GWAS Module**

   * Runs after QC
   * Filters:

     * SNP missingness > 0.05
     * Sample missingness > 0.05
     * MAF < 0.01
     * HWE p < 1e-5
     * Related samples (IBD-based pruning)
   * PCA: If user does not specify PCs, select top 3 or those explaining ≥80% variance

     * Save PCs as covariates in a `covariates/` folder
     * Allow user to add other covariates

4. **Harmonization Module**

   * Uses my existing script (based on GRCh37 and `bcftools`)
   * Corrects strand orientation and generates harmonization reports

---

### ✅ Info Module Validation Features:

#### **Critical Issues (Must Fix):**
- **✅ FIXED: Duplicate Individual IDs:** Now properly detects space-delimited format
- **Special characters in sample IDs:** Spaces, symbols that break parsing
- **Duplicate SNP IDs:** Will cause analysis failures

#### **Recommended Fixes:**
- **Medium Priority:** Format standardization (alphanumeric + underscore/hyphen)
- **Low Priority:** Multiple samples per family (informational)

#### **Fix Commands Generated:**
- Automatic duplicate removal commands
- ID cleaning and standardization scripts  
- PLINK-compatible solutions for each issue type

#### **Validation Outputs:**
- `INFO_validation_issues_*.tsv` - Detailed issue list with severity
- `INFO_recommendations_*.txt` - Step-by-step fix instructions
- `duplicate_IIDs_*.txt` - List of problematic Individual IDs with counts
- `duplicate_IID_lines_*.txt` - **NEW: Actual .fam file lines with duplicates**
- `family_sizes_*.txt` - **NEW: Summary of family sizes for context**
- `invalid_IIDs_*.txt` - Sample IDs with formatting issues
- Enhanced HTML report with visual validation summary

#### **🐛 Bug Fix Log:**
- **Issue:** Duplicate Individual IDs not detected despite manual verification showing duplicates (C11, C12 appearing twice)
- **Root Cause:** Incorrect file parsing - using `cut -f2` (tab-delimited) instead of `awk '{print $2}'` (space-delimited)
- **Solution:** Fixed all parsing commands to use proper space-delimited format for .fam files
- **Verification:** Added detailed logging and debugging output to compare manual vs automated detection
- **Additional:** Created supplementary files showing actual duplicate lines and family size summaries