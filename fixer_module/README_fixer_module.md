# 🔧 PLINK Data Fixer Module

## Overview

The PLINK Data Fixer Module is a comprehensive tool designed to identify and fix common issues in PLINK binary files (.bed, .bim, .fam). This module addresses two main categories of problems:

1. **Sample ID Issues**: Duplicate sample IDs and invalid characters in sample names
2. **SNP Issues**: Duplicate rsIDs and duplicate chromosome:position combinations

## 🎯 Purpose

This module ensures data quality and consistency in PLINK files before downstream analysis by:
- Resolving duplicate sample identifiers with systematic renaming
- Cleaning invalid characters from sample names
- Handling duplicate SNP identifiers by replacing with standard missing notation
- Removing or managing SNPs with identical genomic positions

## 📁 Files Structure

```
fixer_module/
├── fixer_module.sh              # Main module script
├── sample_fixer.sh              # Sample ID fixing script
├── snp_fixer.sh                # SNP fixing script
├── generate_fixer_report.py     # Report generation script
├── fixer_config_template.yaml   # Configuration template
└── README_fixer_module.md       # This documentation
```

## 🚀 Quick Start

### Basic Usage
```bash
# Fix PLINK files with default settings
./fixer_module.sh --bfile mydata --out mydata_fixed

# Generate configuration template
./fixer_module.sh --conftemp

# Use custom configuration
./fixer_module.sh --bfile mydata --out mydata_fixed --config my_config.yaml
```

### SLURM Job Submission
```bash
# Generate and submit SLURM job
./fixer_module.sh --bfile mydata --out mydata_fixed --submit
```

## 📋 Input Requirements

### Required Files
- **PLINK Binary Files**: `.bed`, `.bim`, and `.fam` files with the same prefix
- All files must exist and be readable
- Files should follow standard PLINK format specifications

### File Format Expectations
- **.fam file**: Tab-delimited with 6 columns (FID, IID, PID, MID, Sex, Phenotype)
- **.bim file**: Tab-delimited with 6 columns (CHR, SNP, CM, BP, A1, A2)
- **.bed file**: Binary genotype data

## 🔧 Fixing Capabilities

### Sample ID Fixes

#### 1. Duplicate Sample IDs
- **Problem**: Multiple samples with identical Family ID + Individual ID combinations
- **Solution**: Append suffix (default: `_dup1`, `_dup2`, etc.) to subsequent duplicates
- **Example**: `FAM001 IND001` → First kept as is, second becomes `FAM001 IND001_dup1`

#### 2. Invalid Characters
- **Problem**: Sample names containing special characters, spaces, or symbols
- **Solution**: Replace invalid characters with underscores
- **Default allowed**: Letters (A-Z, a-z), numbers (0-9), underscores (_), hyphens (-)
- **Example**: `FAM-001 IND@001` → `FAM-001 IND_001`

### SNP Fixes

#### 1. Duplicate rsIDs
- **Problem**: Multiple SNPs with identical rsID identifiers
- **Solution**: Replace duplicate rsIDs with '.' (missing notation)
- **Logic**: First occurrence keeps original rsID, subsequent duplicates get '.'
- **Example**: Two SNPs with rsID `rs123456` → First keeps `rs123456`, second becomes `.`

#### 2. Duplicate chr:pos
- **Problem**: Multiple SNPs at identical chromosome:position coordinates
- **Solution**: Remove duplicates or keep only first occurrence
- **Options**:
  - `keep_first_duplicate: true` → Keep first occurrence, remove others
  - `keep_first_duplicate: false` → Remove all occurrences of duplicates
- **Example**: Three SNPs at `chr1:12345` → Only first is retained

## 📊 Output Structure

The module creates a structured output directory:

```
results/fixer/
├── archive/                     # Original input files (if archiving enabled)
│   ├── input.bed
│   ├── input.bim
│   └── input.fam
├── logs/                        # Processing logs
│   └── fixer_module_YYYYMMDD_HHMMSS.log
├── plots/                       # Visualization outputs
│   ├── FIXER_snp_distribution.png
│   └── FIXER_snp_distribution.pdf
├── tables/                      # Reports and statistics
│   ├── FIXER_sample_changes.tsv
│   ├── FIXER_sample_stats.md
│   ├── FIXER_snp_changes.tsv
│   ├── FIXER_snp_stats.md
│   └── FIXER_comprehensive_report.html
├── output_fixed.bed             # Fixed binary genotype file
├── output_fixed.bim             # Fixed marker information file
└── output_fixed.fam             # Fixed sample information file
```

## 📈 Reports Generated

### 1. Sample Changes Report (`FIXER_sample_changes.tsv`)
Detailed log of all sample ID modifications:
```
Change_Type    Original_FID    Original_IID    New_FID    New_IID    Description
DUPLICATE      FAM001         IND001          FAM001     IND001_dup1    Resolved duplicate sample ID
INVALID_CHARS  FAM@002        IND 002         FAM_002    IND_002        Fixed invalid characters
```

### 2. SNP Changes Report (`FIXER_snp_changes.tsv`)
Detailed log of all SNP modifications:
```
Change_Type           Chromosome    Position    Original_rsID    New_rsID    Description
DUPLICATE_RSID        1            12345       rs123456         .           Duplicate rsID replaced
DUPLICATE_CHRPOS_REMOVED    2      67890       rs789012         -           Duplicate chr:pos removed
```

### 3. Comprehensive HTML Report
Interactive HTML report with:
- Summary statistics and visualizations
- Detailed change logs
- Processing parameters used
- File generation information

## ⚙️ Configuration Options

### Configuration File Format (YAML)
```yaml
sample_fixing:
  fix_duplicates: true
  fix_invalid_chars: true
  allowed_chars: "A-Za-z0-9_-"
  duplicate_suffix: "_dup"

snp_fixing:
  fix_duplicate_rsid: true
  fix_duplicate_chrpos: true
  keep_first_duplicate: true

output:
  generate_reports: true
  archive_originals: true
  create_plots: true
```

### Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `fix_duplicates` | `true` | Enable duplicate sample ID fixing |
| `fix_invalid_chars` | `true` | Enable invalid character fixing |
| `allowed_chars` | `"A-Za-z0-9_-"` | Regex pattern for allowed characters |
| `duplicate_suffix` | `"_dup"` | Suffix for duplicate resolution |
| `fix_duplicate_rsid` | `true` | Replace duplicate rsIDs with '.' |
| `fix_duplicate_chrpos` | `true` | Handle duplicate chr:pos |
| `keep_first_duplicate` | `true` | Keep first occurrence of duplicate chr:pos |

## 🖥️ HPC Integration

### SLURM Job Generation
The module automatically generates SLURM job scripts with:
- Appropriate resource allocation (4 CPUs, 8GB RAM, 2 hours)
- Module loading for PLINK and Python
- Email notifications
- Error and output logging

### Resource Requirements
- **CPU**: 4 cores (adjustable in config)
- **Memory**: 8GB (scales with dataset size)
- **Time**: 2 hours (conservative estimate)
- **Storage**: ~2x input file size for outputs

## 🔍 Quality Assurance

### Pre-processing Checks
- Verify all required input files exist
- Check file format consistency
- Validate file readability and permissions

### Processing Validation
- Log all modifications with timestamps
- Count and report changes by category
- Preserve original files (if archiving enabled)
- Generate checksums for verification

### Post-processing Verification
- Compare input vs output statistics
- Validate file format integrity
- Generate comprehensive reports

## 🛠️ Troubleshooting

### Common Issues

#### 1. "Input file not found"
**Cause**: Missing or incorrectly specified input files
**Solution**: Verify file paths and ensure all .bed, .bim, .fam files exist

#### 2. "No changes made"
**Cause**: Input files already clean or fixes disabled in configuration
**Solution**: Check configuration settings and input data quality

#### 3. "Python plots not generated"
**Cause**: Missing Python dependencies (matplotlib, pandas)
**Solution**: Install required packages or disable plotting in configuration

#### 4. "SLURM job submission failed"
**Cause**: SLURM not available or incorrect configuration
**Solution**: Check HPC environment and module availability

### Performance Optimization

#### For Large Datasets (>1M SNPs)
- Use HPC/SLURM submission
- Enable chunked processing in advanced configuration
- Consider temporary directory on fast storage

#### For Memory-Limited Systems
- Reduce chunk size in configuration
- Disable intermediate file backup
- Process samples and SNPs separately

## 📚 Examples

### Example 1: Basic Fixing
```bash
# Fix all common issues with default settings
./fixer_module.sh --bfile study_data --out study_data_clean
```

### Example 2: Custom Configuration
```bash
# Generate configuration template
./fixer_module.sh --conftemp

# Edit fixer_config_template.yaml as needed
# Then run with custom config
./fixer_module.sh --bfile study_data --out study_data_clean --config my_fixer_config.yaml
```

### Example 3: HPC Submission
```bash
# Submit to SLURM queue
./fixer_module.sh --bfile large_study --out large_study_fixed --submit
```

### Example 4: Sample-only Fixing
```yaml
# In configuration file - disable SNP fixing
snp_fixing:
  fix_duplicate_rsid: false
  fix_duplicate_chrpos: false
```

## 🔗 Integration with Pipeline

This module integrates seamlessly with other pipeline components:

### Upstream Dependencies
- Raw PLINK files from genotyping or conversion tools
- Quality control modules may benefit from pre-fixing

### Downstream Applications
- Quality control modules
- Population structure analysis
- Association analysis
- Data export and conversion

### Workflow Integration
```bash
# Typical workflow
./fixer_module.sh --bfile raw_data --out clean_data
./qc_module.sh --bfile clean_data --out qc_data
./pca_module.sh --bfile qc_data --out pca_results
```

## 📞 Support

For issues, questions, or contributions:
- **Author**: Alsamman M. Alsamman
- **Email**: alsammana@omrf.org
- **Documentation**: Follow the genomic pipeline development guide
- **Logs**: Check detailed logs in `results/fixer/logs/` directory

## 🔄 Version History

- **v1.0**: Initial implementation with sample and SNP fixing capabilities
- Comprehensive reporting and visualization
- HPC/SLURM integration
- Configurable parameters and processing options
