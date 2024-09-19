#!/bin/bash

#############################################
# Color Definitions                         #
#############################################
# Reset
 Color_Off=$'\033[0m'       # Text Reset
 
 # Regular Colors
 Black=$'\033[0;30m'        # Black
 Red=$'\033[0;31m'          # Red
 Green=$'\033[0;32m'        # Green
 Yellow=$'\033[0;33m'       # Yellow
 Blue=$'\033[0;34m'         # Blue
 Purple=$'\033[0;35m'       # Purple
 Cyan=$'\033[0;36m'         # Cyan
 White=$'\033[0;37m'        # White

print_info(){
 dt=$(date '+%d/%m/%Y %H:%M:%S')
 echo "[${Cyan}${dt}${Color_Off}] [${Green}info${Color_Off}] ${1}"
} 

print_error(){
 dt=$(date '+%d/%m/%Y %H:%M:%S')
 echo "[${Cyan}${dt}${Color_Off}] [${Red}error${Color_Off}] ${1}"
} 

clean_up(){
 print_error "Script interrupted del ${tmpdir_dv}"
 pkill run_deepvariant
 pkill run_honey_deepvariant.sh
}


################################################################################
# Help                                                                         #
################################################################################
Help()
{
   # Display Help
   echo "Add description of the script functions here."
   echo
   echo "Syntax: run_honey_deepvariant.sh [-g|h|s|t|f|w|o|b|sm|ref|d]"
   echo "options:"
   echo "-h     Print this Help."
   echo "-x     sample sex. It can be M (male) or F (female). If male (Required)"
   echo "-t     Number of threads to use. (Required)"
   echo "-m     Hybrid Model. It can be HYBRID_ONT_R904_ILLUMINA or HYBRID_ONT_R104_ILLUMINA. (Required)"
   echo "-o     Output directory. (Required)"
   echo "-b     Path to the merged ONT-Illumina BAM file. (Required)"
   echo "-s     Sample name. (Required)"
   echo "-r     Path to the reference fasta file on which reads were aligned. (Required)"
   echo "-f     Faster call. Default is false.  Use variant filters vsc_min_count_snps=3, vsc_min_fraction_snps=0.1, vsc_min_count_indels=3, vsc_min_fraction_indels=0.1 (Optional)"
   echo "-g     Output also the gvcf. Default false. (Optional)"
   echo "-c     Cleanup folder with single chromosomes. Default true. (Optional)"
   echo
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
declare -i count=0
FAST="false"
GVCF="false"
CLEAN="true"
while getopts ":hg:f:s:t:m:o:b:x:r:c:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      x)
         SEX=${OPTARG}
         ((count++))
         ;;
      f)
	FAST=${OPTARG}
	;;
      t)
         THREADS=${OPTARG}
         ((count++))
         ;;
      m)
         MODEL_TYPE=${OPTARG}
         ((count++))
         ;;
      o)
         OUTPUT_DIR=${OPTARG}
         ((count++))
         ;;
      b) 
         BAM=${OPTARG}
         ((count++))
         ;;
      s)
         SAMPLE=${OPTARG}
         ((count++))
         ;;
      r)
         REF=${OPTARG}
         ((count++))
         ;;
      g)
         GVCF=${OPTARG}
         ;;
      c)
         CLEAN=${OPTARG}
         ;;
      :)
         print_error "Option -${OPTARG} requires an argument."
         exit 1
         ;;
     \?) # incorrect option
         print_error "Invalid Input option -${OPTARG}"
         exit;;
   esac
done

# Check the number of input args correspond
if [[ ${count} == 0 ]]; then
   print_error "No arguments in input, please see the help (-h)"
   exit
elif [[ ${count} -lt 7 ]]; then
      print_error "Missing some input arguments, please see the help (-h)"
      exit
fi

# check all required files exist
if [ ! -f ${BAM} ]; then
   print_error "Hybrid BAM file not found"
   exit 1
fi

if [ ! -f ${REF} ]; then
   print_error "Reference FASTA file file not found"
   exit 1
fi

SEX=$(echo "${SEX}" | awk '{print toupper($0)}')

if [ ${FAST} == "true" ]; then
 vc_filter="--make_examples_extra_args=vsc_min_count_snps=3,vsc_min_fraction_snps=0.15,vsc_min_count_indels=3,vsc_min_fraction_indels=0.1"
else
 vc_filter=""
fi

if [ ${SEX} == "M" ]; then
   REGIONS="chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22"
else
   REGIONS="chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10 chr11 chr12 chr13 chr14 chr15 chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX"
fi


mkdir -p "${OUTPUT_DIR}/${SAMPLE}/logs"
tmpdir_chrs=$(mktemp -d --tmpdir=${OUTPUT_DIR}/${SAMPLE})
print_info "1/2 Honey Deepvariant Processing ${SAMPLE}..."
for chr in ${REGIONS}
do
   print_info "Processing chromosome ${chr}..."
   #intermediate_dir=$(mktemp -d --tmpdir="${OUTPUT_DIR}/${SAMPLE}")

   if [ ${GVCF} != "false" ]; then
      opt_args=" --output_gvcf=${tmpdir_chrs}/${chr}_honey_deepvariant_output.g.vcf.gz"
   else
      opt_args=""
   fi

   trap clean_up 1 2 3 6
   ( /opt/deepvariant/bin/run_deepvariant \
        --model_type=${MODEL_TYPE} \
        --ref=${REF} \
        --reads=${BAM} \
        --output_vcf="${tmpdir_chrs}/${chr}_honey_deepvariant_output.vcf.gz" \
        --num_shards=${THREADS} \
        --regions ${chr} "${vc_filter} ${opt_args}"
        # --intermediate_results_dir ${intermediate_dir}
   ) > "${OUTPUT_DIR}/${SAMPLE}/logs/${SAMPLE}_honey_deepvariant_${chr}.log" 2>&1

   #rm -rf ${intermediate_dir}
done


if [ ${SEX} == "M" ]; then
   chr="chrX chrY"
   print_info "Processing chromosome ${chr}..."
   #intermediate_dir=$(mktemp -d --tmpdir="${OUTPUT_DIR}/${SAMPLE}")

   if [ ${GVCF} != "false" ]; then
      opt_args=" --output_gvcf=${tmpdir_chrs}/${chr}_honey_deepvariant_output.g.vcf.gz"
   else
      opt_args=""
   fi

   trap clean_up 1 2 3 6
   ( /opt/deepvariant/bin/run_deepvariant \
        --model_type=${MODEL_TYPE} \
        --ref=${REF} \
        --reads=${BAM} \
        --output_vcf="${tmpdir_chrs}/chrXY_honey_deepvariant_output.vcf.gz" \
        --num_shards=${THREADS} \
        --regions ${chr} \
        --haploid_contigs="chrX,chrY" \
        --par_regions_bed="/opt/deepvariant/resource/GRCh38_PAR.bed" ${vc_filter} ${opt_args}
        # --intermediate_results_dir ${intermediate_dir}
   ) > "${OUTPUT_DIR}/${SAMPLE}/logs/${SAMPLE}_honey_deepvariant_chrXY.log" 2>&1

   #rm -rf ${intermediate_dir}
fi



print_info "2/2 Merging the results..."
find "${tmpdir_chrs}/" -type f -name "*.vcf.gz" > "${tmpdir_chrs}/vcf.list"
ionice -c 3 bcftools concat -a \
        --threads ${THREADS} \
        --file-list "${tmpdir_chrs}/vcf.list" | \
        bcftools sort - -o - | \
        bgzip -c > "${OUTPUT_DIR}/${SAMPLE}/${SAMPLE}_honey_deepvariant_output.vcf.gz"
tabix -p vcf "${OUTPUT_DIR}/${SAMPLE}/${SAMPLE}_honey_deepvariant_output.vcf.gz"

if [ ${GVCF} != "false" ]; then
   find "${tmpdir_chrs}/" -type f -name "*.g.vcf.gz" > "${tmpdir_chrs}/gvcf.list"
   ionice -c 3 bcftools concat -a \
           --threads ${THREADS} \
           --file-list "${tmpdir_chrs}/gvcf.list" | \
           bcftools sort - -o - | \
           bgzip -c > "${OUTPUT_DIR}/${SAMPLE}/${SAMPLE}_honey_deepvariant_output.g.vcf.gz"
   tabix -p vcf "${OUTPUT_DIR}/${SAMPLE}/${SAMPLE}_honey_deepvariant_output.g.vcf.gz"
   rm ${tmpdir_chrs}/gvcf.list
fi



if [ "${CLEAN}" == "true" ]; then 
   rm -rf ${tmpdir_chrs}
else
   rm ${tmpdir_chrs}/vcf.list
   mv ${tmpdir_chrs} "${OUTPUT_DIR}/${SAMPLE}/vcf_split_by_chr"
fi

print_info "${SAMPLE} FINISHED!!"
