# 🧬 Dataset Information Module

## Overview
The Dataset Information Module is the first step in the genomic data analysis pipeline. It provides comprehensive analysis and reporting of PLINK dataset characteristics, following the development guidelines specified in `devguide.md`.

## Features

### 📊 Core Analysis
- **Dataset Summary**: Sample counts, SNP counts, file sizes
- **Quality Metrics**: MAF distributions, missingness patterns, HWE statistics
- **Sample Demographics**: Sex distribution, phenotype distribution (binary)
- **Genomic Structure**: Chromosomal distribution of SNPs
- **Data Integrity**: Duplicate ID detection (samples and SNPs)

### 📈 Visualizations
- MAF distribution histograms
- SNP missingness distribution plots
- Chromosomal SNP distribution charts
- Summary statistics tables

### 📝 Comprehensive Reporting
- HTML report with all key findings
- TSV tables for downstream analysis
- Detailed processing logs
- Archive of original input files

## Usage

### Basic Usage
```bash
./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info
```

### With Configuration File
```bash
# Generate configuration template
./info_module.sh --conftemp

# Use configuration file
./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info --config config.yaml
```

### HPC/SLURM Integration
```bash
# Generate SLURM submission script
./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info --slurm

# Submit the generated job
sbatch results/info/submit_info_module.sh
```

### Other Options
```bash
# Dry run (show commands without executing)
./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info --dry-run

# Verbose output
./info_module.sh --plink-prefix /path/to/your/data --output-dir results/info --verbose

# Help
./info_module.sh --help
```

## Input Requirements

### Required Files
- `data.bed` - PLINK binary genotype file
- `data.bim` - PLINK variant information file  
- `data.fam` - PLINK sample information file

### File Format Expectations
- Standard PLINK binary format
- Sample IDs in .fam file (FID, IID columns)
- SNP IDs in .bim file
- Binary phenotypes (1=control, 2=case, -9/0=missing)

## Output Structure

```
results/info/
├── archive/                    # Original input files
│   ├── data.bed
│   ├── data.bim
│   └── data.fam
├── logs/                       # Processing logs
│   ├── info_module_YYYY-MM-DD_HH-MM-SS.log
│   ├── plink_freq_YYYY-MM-DD_HH-MM-SS.log
│   ├── plink_missing_YYYY-MM-DD_HH-MM-SS.log
│   └── plink_hardy_YYYY-MM-DD_HH-MM-SS.log
├── plots/                      # Visual outputs
│   ├── MAF_distribution.pdf
│   ├── missingness_distribution.pdf
│   ├── chromosome_distribution.pdf
│   └── generate_plots.R
├── tables/                     # Summary data
│   ├── INFO_file_summary_YYYY-MM-DD_HH-MM-SS.tsv
│   ├── INFO_chromosome_distribution_YYYY-MM-DD_HH-MM-SS.tsv
│   ├── INFO_basic_stats.frq    # PLINK frequency output
│   ├── INFO_basic_stats.lmiss  # PLINK SNP missingness
│   ├── INFO_basic_stats.imiss  # PLINK sample missingness
│   └── INFO_basic_stats.hwe    # PLINK Hardy-Weinberg
├── INFO_report_YYYY-MM-DD_HH-MM-SS.html  # Comprehensive report
└── submit_info_module.sh       # SLURM submission script (if generated)
```

## Key Output Files

### Summary Tables
1. **File Summary** (`INFO_file_summary_*.tsv`)
   - Total samples and SNPs
   - Duplicate ID counts
   - Sex and phenotype distributions
   - Chromosome counts

2. **Chromosome Distribution** (`INFO_chromosome_distribution_*.tsv`)
   - SNP counts per chromosome
   - Percentage distribution

3. **PLINK Statistics**
   - `.frq`: Allele frequencies
   - `.lmiss/.imiss`: Missingness by SNP/sample
   - `.hwe`: Hardy-Weinberg equilibrium tests

### Visualizations
- **MAF Distribution**: Histogram of minor allele frequencies
- **Missingness Distribution**: Pattern of missing genotypes
- **Chromosome Distribution**: SNP distribution across chromosomes

### HTML Report
Comprehensive report including:
- Dataset overview with key metrics
- Quality assessment summary
- File inventory
- Processing parameters used

## Dependencies

### Required Software
- **PLINK** (v1.9 or v2.0) - For genetic data analysis
- **Standard Unix tools** - awk, cut, sort, wc, etc.

### Optional Software (for enhanced plots)
- **R** with ggplot2 and data.table packages
- **Python** with matplotlib/seaborn (alternative plotting)

### HPC Environment
- SLURM workload manager (for HPC integration)
- Environment modules (module load commands in SLURM script)

## Configuration Options

Generate a configuration template with:
```bash
./info_module.sh --conftemp
```

### Available Settings
```yaml
analysis:
  detailed_chr_stats: true       # Per-chromosome analysis
  phenotype_analysis: true       # Phenotype distribution
  population_structure: false    # Basic PCA preview

plots:
  histogram_bins: 50             # Histogram resolution
  figure_width: 10               # Plot dimensions
  figure_height: 8
  dpi: 300                       # Plot quality

output:
  generate_html_report: true     # Comprehensive report
  save_intermediate_files: true  # Keep intermediate files
  compress_plots: false          # Plot format options

resources:
  cpus: 4                        # SLURM resources
  memory_gb: 8
  time_hours: 2
  partition: "short"
  email: "user@institution.edu"
```

## Error Handling

The module includes comprehensive error handling:
- **Input validation**: Checks for required PLINK files
- **Graceful failures**: Meaningful error messages
- **Logging**: All operations logged with timestamps
- **Recovery**: Continues processing even if optional steps fail

## Integration with Pipeline

This module is designed as the **first step** in the genomic analysis pipeline:

1. **Information Module** ← *You are here*
2. Quality Control Module
3. GWAS Module  
4. Harmonization Module

### Outputs for Downstream Modules
- Validated input files in `archive/`
- Quality metrics for QC module planning
- Sample/SNP counts for resource estimation
- Identified issues (duplicates, missing data) for correction

## Troubleshooting

### Common Issues
1. **PLINK not found**: Ensure PLINK is installed and in PATH
2. **Permission denied**: Check file permissions and directory write access
3. **Missing R packages**: Install with `install.packages(c("ggplot2", "data.table"))`
4. **Large datasets**: Increase memory allocation in SLURM script

### Log Files
Check the following logs for debugging:
- Main log: `logs/info_module_*.log`
- PLINK logs: `logs/plink_*_*.log`
- Plot generation: `logs/plots_*.log`

## Development Notes

This module follows the genomic pipeline development guidelines:
- ✅ Independent and self-contained
- ✅ Command-line arguments (no hardcoded paths)
- ✅ Comprehensive documentation
- ✅ Config file support with `--conftemp`
- ✅ SLURM integration
- ✅ Standardized output structure
- ✅ Error handling and logging
- ✅ Archive of original inputs

## Version History

- **v1.0.0**: Initial implementation with core functionality
  - Basic dataset statistics
  - PLINK integration
  - HTML reporting
  - SLURM support
