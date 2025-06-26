# 🧬 Genomic Pipeline Development Guide

## 🎯 Core Principle
**Every module you create must be independent, self-contained, and reusable.**

---

## 📋 Essential Requirements Checklist

### ✅ Before Starting Any Module
- [ ] Module accepts PLINK binary files (.bed, .bim, .fam) as input
- [ ] All file paths are command-line arguments (no hardcoded paths)
- [ ] Script includes comprehensive documentation header
- [ ] Config file support with `--conftemp` option implemented

---

## 1️⃣ Module Structure & Design

### 📂 **File Organization**
- **Input**: Accept all file paths as command-line arguments
- **Output Structure**: 
  ```
  results/
  ├── {module_name}/
  │   ├── archive/          # Original input files
  │   ├── logs/             # Log files
  │   ├── plots/            # Visual outputs
  │   └── tables/           # Summary data
  ```

### 🏷️ **Naming Conventions**
- **Output Files**: Use standardized prefixes (`QC_`, `PCA_`, `GWAS_`, `INFO_`)
- **Modified Data**: Add descriptive suffixes (`_filtered`, `_fixed`, `_cleaned`)

### 📖 **Documentation Requirements**
```bash
#!/bin/bash
# =============================================================================
# MODULE NAME: [Brief description]
# PURPOSE: [What this module does]
# INPUTS: [Required input files and formats]
# OUTPUTS: [Generated files and their purposes]
# USAGE: [Clear command example]
# =============================================================================
```

### 💻 **Code Standards**
- **Languages**: Python or Bash preferred
- **Style**: Clean, well-commented code
- **Error Handling**: Graceful failure with meaningful messages

---

## 2️⃣ Configuration System

### ⚙️ **Config File Support**
- **Format**: YAML
- **Parameters**: MAF, HWE, missingness, IBD thresholds
- **Template**: `--conftemp` generates example config

### 📝 **Parameter Management**
- **Defaults**: Sensible fallback values
- **Logging**: Record all parameters used (from file or defaults)
- **Validation**: Check parameter ranges and compatibility

---

## 3️⃣ HPC & SLURM Integration

### 🚀 **Job Submission**
```bash
#SBATCH --job-name={module_name}
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --mail-user=alsammana@omrf.org
#SBATCH --mail-type=ALL
```

### 🔧 **Resource Optimization**
- **CPU**: Match to analysis requirements
- **Memory**: Scale with dataset size
- **Time**: Conservative estimates with buffer

---

## 4️⃣ Output Standards

### 📊 **Required Output Files**
1. **Summary Tables** (`.tsv`/`.csv`)
2. **Visual Plots** (`.pdf`/`.png`)  
3. **Detailed Log** (`.log`)
4. **Comprehensive Report** (`.md`/`.html`)

### 🗂️ **Data Preservation**
- **Archive**: Copy original inputs to `archive/` subdirectory
- **Versioning**: Timestamp all outputs
- **Metadata**: Save processing parameters with results

---

## 5️⃣ Quality Assurance

### 🛡️ **Error Prevention**
- **Pre-flight Checks**: Verify input files exist
- **Validation**: Check file formats and integrity  
- **Graceful Failure**: Meaningful error messages, non-zero exit codes

### 📝 **Comprehensive Logging**
```
[TIMESTAMP] Module started
[TIMESTAMP] Input validation: PASSED
[TIMESTAMP] Processing 1,234 samples, 567,890 SNPs
[TIMESTAMP] Applied filters: MAF > 0.01, missingness < 0.05
[TIMESTAMP] Results: 1,200 samples, 456,789 SNPs retained
[TIMESTAMP] Module completed successfully
```

### 🔄 **Reproducibility Features**
- **Config Archive**: Save exact parameters used
- **Dry Run**: `--dry-run` shows commands without execution
- **Version Control**: Log software versions and parameters

---

## 6️⃣ Special Requirements

### 🔍 **Information Module Priority**
- **Must Generate**: Both summary tables AND visual plots
- **Comprehensive Stats**: Sample counts, MAF distributions, quality metrics
- **Visual Outputs**: Histograms, scatter plots, summary charts

### ♻️ **Code Reuse Policy**
- **Priority**: Use existing validated scripts when possible
- **Integration**: Adapt existing tools to fit pipeline standards
- **Documentation**: Credit and document any reused components

---

## 🚦 Quick Start Workflow

1. **Design Phase**
   - [ ] Define module purpose and scope
   - [ ] Plan input/output file structure
   - [ ] Choose appropriate tools and methods

2. **Development Phase**
   - [ ] Create script template with documentation
   - [ ] Implement config file support
   - [ ] Add error handling and logging
   - [ ] Generate SLURM submission script

3. **Testing Phase**
   - [ ] Test with sample data
   - [ ] Validate all output files generated
   - [ ] Verify error handling works
   - [ ] Check SLURM job submission

4. **Deployment Phase**
   - [ ] Final documentation review
   - [ ] Integration testing with pipeline
   - [ ] Performance optimization if needed