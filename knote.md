### 
I’m developing a modular genomic data analysis pipeline for PLINK-formatted datasets. The pipeline will consist of independent stages, each organized in separate folders according to analysis type (e.g., QC, GWAS, harmonization, etc.).

### Key Notes:

* **Each script will be written and tested individually.**
* **You should not write the full pipeline at once.**
* **Start with the `info` module.**

---

### Overall Pipeline Structure:

1. **Information Module (First Step)**

   * Summarizes key dataset stats:

     * Number of SNPs and samples
     * SNP and sample name duplications
     * Chromosomal distribution
     * Sample counts by FID and sex
     * Phenotype distribution (binary only, since we work on Lupus)
   * Input: PLINK files
   * Output: Tables, summary plots, and a comprehensive report (saved in output folder)

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