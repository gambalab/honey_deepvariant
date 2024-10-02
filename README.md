# HONEY Deepvariant

This is a fork of Deepvariant, tailored for Hybrid Oxford Nanopore tEchnologY (HONEY Deepvariant) and Ilumina sequencing, as described in our manuscript available HERE (link to add).

Honey Deepvariant is based on Deepvariant version 1.6.1

DeepVariant is a deep learning-based variant caller that takes aligned reads (in
BAM or CRAM format), produces pileup image tensors from them, classifies each
tensor using a convolutional neural network, and finally reports the results in
a standard VCF or gVCF file.

DeepVariant supports germline variant-calling in diploid organisms.

## How to install 
To install the honey deepvariant Docker/Singularity image, run the following commands:

```
# 1. Install with Singularity
singularity pull docker://gambalab/honey_deepvariant:1.6.1

# 2. Install with Docker
docker pull gambalab/honey_deepvariant:1.6.1
```

## How to run Honey DeepVariant

We recommend using Singularity solution and use our optimezed script contained into the singularity image that will take care of everythink and be faster since it runs chromosome by chromosome.

Note: Only HG38 is supported and chromosomes must have suffix chr.

```
# Let's first define a honey_deepvariant_exec variable to excec the command 
HONEY_exec="singularity exec --bind /usr/lib/locale/ path/to/honey_deepvariant_1.6.1.sif"

# Let's see the help first
${HONEY_exec} run_honey_deepvariant.sh -h
```

```
Hybrid Oxford Nanopore tEchnologY Deepvariant (HONEY Deepvariant)

Syntax: run_honey_deepvariant.sh [-g|h|s|t|f|w|o|b|s|m|r|d]
options:
-h     Print this Help.
-x     sample sex. It can be M (male) or F (female). If male (Required)
-t     Number of threads to use. (Required)
-m     Hybrid Model. It can be HYBRID_ONT_R904_ILLUMINA or HYBRID_ONT_R104_ILLUMINA. (Required)
-o     Output directory. (Required)
-b     Path to the merged ONT-Illumina BAM file. (Required)
-s     Sample name. (Required)
-r     Path to the reference fasta file on which reads were aligned. (Required)
-f     Faster call. Default is false.  Use variant filters vsc_min_count_snps=3, vsc_min_fraction_snps=0.1, vsc_min_count_indels=3, vsc_min_fraction_indels=0.1 (Optional)
-g     Output also the gvcf. Default false. (Optional)"
-c     Cleanup folder with single chromosomes. Default true. (Optional)
```

So a typical case of use will be something like this:
```
${HONEY_exec} \
 -x F \
 -t 32 \
 -m HYBRID_ONT_R104_ILLUMINA \
 -o /path/to/output/directory \
 -b /path/to/hybrid/bam/file/ \
 -s ${SAMPLE} \
 -r /path/to/ref/genome \
 -g true

```

Otherwise classic deepvariant command as in the standard deepvariant tool can be used.  In this case the command will look like this:

```
# Docker example
BIN_VERSION="1.6.1"
docker run \
  -v "YOUR_INPUT_DIR":"/input" \
  -v "YOUR_OUTPUT_DIR:/output" \
  gambalab/honey_deepvariant:"${BIN_VERSION}" \
  /opt/deepvariant/bin/run_deepvariant \
  --model_type=HYBRID_ONT_R104_ILLUMINA \ **Replace this string with exactly one of the following [HYBRID_ONT_R904_ILLUMINA or HYBRID_ONT_R104_ILLUMINA]**
  --ref=/input/YOUR_REF \
  --reads=/input/YOUR_HYBRID_BAM \
  --output_vcf=/output/YOUR_OUTPUT_VCF \
  --output_gvcf=/output/YOUR_OUTPUT_GVCF \
  --num_shards=$(nproc) \ **This will use all your cores to run make_examples. Feel free to change.**
  --logging_dir=/output/logs \ **Optional. This saves the log output for each stage separately.
  --haploid_contigs="chrX,chrY" \ **Optional. Heterozygous variants in these contigs will be re-genotyped as the most likely of reference or homozygous alternates. For a sample with karyotype XY, it should be set to "chrX,chrY" for GRCh38 and "X,Y" for GRCh37. For a sample with karyotype XX, this should not be used.
  --par_regions_bed="/input/GRCh3X_par.bed" \ **Optional. If --haploid_contigs is set, then this can be used to provide PAR regions to be excluded from genotype adjustment. Download links to this files are available in this page.
  --dry_run=false **Default is false. If set to true, commands will be printed out but not executed.
```

```
# Singularity example

# Let's first define a honey_deepvariant_exec variable to excec the command 
HONEY_exec="singularity exec --bind /usr/lib/locale/ path/to/honey_deepvariant_1.6.1.sif"

${HONEY_exec} \
  /opt/deepvariant/bin/run_deepvariant \
  --model_type=HYBRID_ONT_R104_ILLUMINA \ **Replace this string with exactly one of the following [HYBRID_ONT_R904_ILLUMINA or HYBRID_ONT_R104_ILLUMINA]**
  --ref=/path/YOUR_REF \
  --reads=/path/YOUR_HYBRID_BAM \
  --output_vcf=/path/output/YOUR_OUTPUT_VCF \
  --output_gvcf=/path/output/YOUR_OUTPUT_GVCF \
  --num_shards=$(nproc) \ **This will use all your cores to run make_examples. Feel free to change.**
  --logging_dir=/path/output/logs \ **Optional. This saves the log output for each stage separately.
  --haploid_contigs="chrX,chrY" \ **Optional. Heterozygous variants in these contigs will be re-genotyped as the most likely of reference or homozygous alternates. For a sample with karyotype XY, it should be set to "chrX,chrY" for GRCh38 and "X,Y" for GRCh37. For a sample with karyotype XX, this should not be used.
  --par_regions_bed="/input/GRCh3X_par.bed" \ **Optional. If --haploid_contigs is set, then this can be used to provide PAR regions to be excluded from genotype adjustment. Download links to this files are available in this page.
  --dry_run=false **Default is false. If set to true, commands will be printed out but not executed.

```

For details on all deepvariant flags and use scenarios, please see original Deepvariant github https://github.com/google/deepvariant

## Disclaimer

NOTE: the content of this research code repository (i) is not intended to be a
medical device; and (ii) is not intended for clinical use of any kind, including
but not limited to diagnosis or prognosis.
