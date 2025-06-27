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
# AUTHOR: Alsamman M. Alsamman
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
- **Parameters**: MAF, HWE, missingness, IBD thresholds, and other
- **Template**: `--conftemp` generates example config

### 📝 **Parameter Management**
- **Defaults**: Sensible fallback values
- **Logging**: Record all parameters used (from file or defaults)
- **Validation**: Check parameter ranges and compatibility

### 🎨 **Configuration File Formatting**
- **Section Headers**: Use descriptive comments with context
  ```yaml
  # Module Loading (for HPC environments)
  modules:
    plink: "plink2/1.90b3w"     # PLINK module to load
    python: "python"           # Python module to load
  ```
- **Inline Comments**: Explain purpose and acceptable values for each parameter
- **Grouping**: Organize related parameters under logical sections
- **Examples**: Include example values and format specifications
- **Documentation**: Each section should be self-explanatory with clear descriptions

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
- **Version Control**: Log software versions and parameters

### ♻️ **Code Reuse Policy**
- **Priority**: Use existing validated scripts when possible
- **Integration**: Adapt existing tools to fit pipeline standards
- **Documentation**: Credit and document any reused components

---

## 7️⃣ Lessons Learned & Best Practices

#### **SLURM Integration Enhancements**
- **Auto-Submit Option**: Add `--submit` flag to automatically run `sbatch` after generating script
- **Module Discovery**: Provide tools to identify available modules on specific HPC systems
- **Fallback Loading**: Implement smart module loading with version fallbacks

#### **Configuration Management**
- **YAML Parsing Issues**: Simple `grep`/`sed` approach more reliable than complex regex
- **Module Specification**: Allow multiple module versions in config for compatibility
- **Environment Detection**: Auto-detect HPC vs standalone environments

#### **YAML Configuration**
- **Keep It Simple**: Use straightforward parsing methods
- **Clear Documentation**: Include examples for different HPC environments

### 📝 **Common Pitfalls & Solutions**

#### **Issue**: "No modules found in configuration file"
**Solution**: Use simple `grep`/`sed` parsing instead of complex regex

#### **Issue**: Module version not available on HPC system
**Solution**: Implement fallback to generic module names

#### **Issue**: Different module names across HPC systems
**Solution**: Provide discovery tools and flexible configuration options

#### **Issue**: Manual SLURM script submission
**Solution**: Add `--submit` option for automatic job submission

### 🚀 **Enhanced Workflow**

#### **Module Development Process**
1. **Start Simple**: Basic functionality first
2. **Test Early**: Use discovery tools to identify system capabilities

#### **User Experience Improvements**
- **One-Command Submission**: `--submit` for direct job submission
- **Environment Setup**: Auto-detect and configure for user's system
- **Clear Error Messages**: Specific guidance for missing tools/modules
- **Flexible Configuration**: Support various HPC environments

### 🎯 **Key Takeaways**

1. **Simplicity Over Complexity**: Simple parsing often more reliable than sophisticated regex
2. **Flexibility is Key**: Support multiple module versions and naming conventions


## PLINK
Always allow no sex samples