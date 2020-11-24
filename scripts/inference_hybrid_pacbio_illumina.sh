#!/bin/bash
# Copyright 2020 Google LLC.

set -euo pipefail

## Preliminaries
# Set a number of shell variables, to make what follows easier to read.
BASE="${HOME}/hybrid-pacbio-illumina-case-study"
BIN_VERSION="1.1.0-rc20201118"

INPUT_DIR="${BASE}/input/data"
REF="GCA_000001405.15_GRCh38_no_alt_analysis_set.fna"
BAM="HG003_hybrid_35x_ilmn_35x_pacb.grch38.phased.bam"
TRUTH_VCF="HG003_GRCh38_1_22_v4.2_benchmark.vcf.gz"
TRUTH_BED="HG003_GRCh38_1_22_v4.2_benchmark.bed"

N_SHARDS="64"

OUTPUT_DIR="${BASE}/output"
OUTPUT_VCF="HG003.output.vcf.gz"
OUTPUT_GVCF="HG003.output.g.vcf.gz"
LOG_DIR="${OUTPUT_DIR}/logs"

# Whether to build docker image.
BUILD_DOCKER="${1:-false}"

# Optional extra flags for DeepVariant.
CUSTOMIZED_MODEL="${2:-}"
MAKE_EXAMPLES_ARGS="${3:-}"
CALL_VARIANTS_ARGS="${4:-}"
POSTPROCESS_VARIANTS_ARGS="${5:-}"
REGIONS="${6:-}"
USE_GPU="${7:-false}"

declare -a extra_args
declare -a happy_args
declare -a docker_args

function setup_test() {

  ## Create local directory structure
  mkdir -p "${OUTPUT_DIR}"
  mkdir -p "${INPUT_DIR}"
  mkdir -p "${LOG_DIR}"


  ## Download extra packages
  # Install aria2 to download data files.
  sudo apt-get -qq -y update
  sudo apt-get -qq -y install aria2

  if ! hash docker 2>/dev/null; then
    echo "'docker' was not found in PATH. Installing docker..."
    # Install docker using instructions on:
    # https://docs.docker.com/install/linux/docker-ce/ubuntu/
    sudo apt-get -qq -y install \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
    sudo apt-get -qq -y update
    sudo apt-get -qq -y install docker-ce
  fi

  GCS_DATA_DIR="https://storage.googleapis.com/deepvariant"
  # Copy the data
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${TRUTH_BED}"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${TRUTH_VCF}"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${TRUTH_VCF}.tbi"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/hybrid-case-study-testdata/${BAM}"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/hybrid-case-study-testdata/${BAM}.bai"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${REF}.gz"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${REF}.gz.fai"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${REF}.gz.gzi"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${REF}.gzi"
  aria2c -c -x10 -s10 -d "${INPUT_DIR}" "${GCS_DATA_DIR}/case-study-testdata/${REF}.fai"

  if [[ "${BUILD_DOCKER}" = true ]]
  then
    if [[ "${USE_GPU}" = true ]]
    then
      IMAGE="deepvariant_gpu:latest"
      sudo docker build \
        --build-arg=FROM_IMAGE=nvidia/cuda:10.0-cudnn7-devel-ubuntu16.04 \
        --build-arg=DV_GPU_BUILD=1 -t deepvariant_gpu .
      echo "Done building GPU Docker image ${IMAGE}."
      docker_args+=( --gpus 1 )
    else
      IMAGE="deepvariant:latest"
      # Pulling twice in case the first one times out.
      sudo docker build -t deepvariant . || \
        (sleep 5 ; sudo docker build -t deepvariant .)
      echo "Done building Docker image ${IMAGE}."
    fi
  else
    if [[ "${USE_GPU}" = true ]]
    then
      IMAGE="google/deepvariant:${BIN_VERSION}-gpu"
      sudo docker pull "${IMAGE}"
      docker_args+=( --gpus 1 )
    else
      IMAGE="google/deepvariant:${BIN_VERSION}"
      sudo docker pull "${IMAGE}"
    fi
  fi
}

function run_deepvariant_with_docker() {
  echo "Run DeepVariant..."
  echo "using IMAGE=$IMAGE"

  if [[ -n $CUSTOMIZED_MODEL ]]
  then
    echo "Copy from gs:// path $CUSTOMIZED_MODEL to ${INPUT_DIR}/"
    gsutil cp "${CUSTOMIZED_MODEL}"/model.ckpt.data-00000-of-00001 "${INPUT_DIR}"
    gsutil cp "${CUSTOMIZED_MODEL}"/model.ckpt.index "${INPUT_DIR}"
    gsutil cp "${CUSTOMIZED_MODEL}"/model.ckpt.meta "${INPUT_DIR}"
    extra_args+=( --customized_model "/input/model.ckpt")
  else
      echo "No custom model specified."
  fi
  if [[ -n $MAKE_EXAMPLES_ARGS ]]
  then
    extra_args+=( --make_examples_extra_args "${MAKE_EXAMPLES_ARGS}")
  fi
  if [[ -n $CALL_VARIANTS_ARGS ]]
  then
    extra_args+=( --call_variants_extra_args "${CALL_VARIANTS_ARGS}")
  fi
  if [[ -n $POSTPROCESS_VARIANTS_ARGS ]]
  then
    extra_args+=( --postprocess_variants_extra_args "${POSTPROCESS_VARIANTS_ARGS}")
  fi
  if [[ -n $REGIONS ]]
  then
    extra_args+=( --regions "${REGIONS}")
    happy_args+=( -l "${REGIONS}")
  fi

  # shellcheck disable=SC2068
  (time ( sudo docker run \
    -v "${INPUT_DIR}:/input" \
    -v "${OUTPUT_DIR}:/output" \
    ${docker_args[@]-} \
    "${IMAGE}" \
    /opt/deepvariant/bin/run_deepvariant \
      --model_type="HYBRID_PACBIO_ILLUMINA" \
      --ref="/input/${REF}.gz" \
      --reads="/input/${BAM}" \
      --output_vcf=/output/${OUTPUT_VCF} \
      --output_gvcf=/output/${OUTPUT_GVCF} \
      --num_shards=${N_SHARDS} \
      --logging_dir="/output/logs" \
      "${extra_args[@]-}"
  echo "Done.")) 2>&1 | tee "${LOG_DIR}/deepvariant_runtime.log"
  echo
}

## Evaluation: run hap.py
echo "Start evaluation with hap.py..."
UNCOMPRESSED_REF="${INPUT_DIR}/${REF}"

function run_happy() {
  # hap.py cannot read the compressed fa, so uncompress
  # into a writable directory. Index file was downloaded earlier.
  zcat <"${INPUT_DIR}/${REF}.gz" >"${UNCOMPRESSED_REF}"

  sudo docker pull pkrusche/hap.py
  # shellcheck disable=SC2068
  ( sudo docker run -i \
  -v "${INPUT_DIR}:${INPUT_DIR}" \
  -v "${OUTPUT_DIR}:${OUTPUT_DIR}" \
  pkrusche/hap.py /opt/hap.py/bin/hap.py \
    "${INPUT_DIR}/${TRUTH_VCF}" \
    "${OUTPUT_DIR}/${OUTPUT_VCF}" \
    -f "${INPUT_DIR}/${TRUTH_BED}" \
    -r "${UNCOMPRESSED_REF}" \
    -o "${OUTPUT_DIR}/happy.output" \
    --engine=vcfeval \
    ${happy_args[@]-}
  ) 2>&1 | tee "${LOG_DIR}/happy.log"
  echo "Done."
}

function main() {
  echo 'Starting the test...'

  setup_test
  run_deepvariant_with_docker
  run_happy 2>&1 | tee "${LOG_DIR}/happy.log"
}

main "$@"