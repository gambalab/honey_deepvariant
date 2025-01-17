# Copyright 2019 Google LLC.
# This is used to build the DeepVariant release docker image.
# It can also be used to build local images, especially if you've made changes
# to the code.
# Example command:
# $ git clone https://github.com/google/deepvariant.git
# $ cd deepvariant
# $ sudo docker build -t honey_deepvariant .
#
# To build for GPU, use a command like:
# $ sudo docker build --build-arg=FROM_IMAGE=nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04 --build-arg=DV_GPU_BUILD=1 -t honey_deepvariant_gpu .


ARG FROM_IMAGE=ubuntu:20.04
# PYTHON_VERSION is also set in settings.sh.
ARG PYTHON_VERSION=3.8
ARG DV_GPU_BUILD=0
ARG VERSION=1.6.1

FROM continuumio/miniconda3 AS conda_setup
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge
RUN conda create -y -n bio \
                    bioconda::bcftools=1.20 \
                    bioconda::samtools=1.20 \
                    bioconda::tabix=0.2.6 \
                    bioconda::sambamba=1.0.1 \
    && conda clean -a

FROM ${FROM_IMAGE} AS builder
COPY --from=conda_setup /opt/conda /opt/conda
LABEL maintainer="https://github.com/google/deepvariant/issues"

ARG DV_GPU_BUILD
ENV DV_GPU_BUILD=${DV_GPU_BUILD}

# Copying DeepVariant source code
COPY . /opt/deepvariant

ARG VERSION
ENV VERSION=${VERSION}

WORKDIR /opt/deepvariant

RUN echo "Acquire::http::proxy \"$http_proxy\";\n" \
         "Acquire::https::proxy \"$https_proxy\";" > "/etc/apt/apt.conf"

RUN ./build-prereq.sh \
  && PATH="${HOME}/bin:${PATH}" ./build_release_binaries.sh  # PATH for bazel

FROM ${FROM_IMAGE}
ARG DV_GPU_BUILD
ARG VERSION
ARG PYTHON_VERSION
ENV DV_GPU_BUILD=${DV_GPU_BUILD}
ENV VERSION ${VERSION}
ENV PYTHON_VERSION ${PYTHON_VERSION}

RUN echo "Acquire::http::proxy \"$http_proxy\";\n" \
         "Acquire::https::proxy \"$https_proxy\";" > "/etc/apt/apt.conf"

WORKDIR /opt/
COPY --from=builder /opt/deepvariant/bazel-bin/licenses.zip .

WORKDIR /opt/deepvariant/bin/
COPY --from=builder /opt/conda /opt/conda
COPY --from=builder /opt/deepvariant/run-prereq.sh .
COPY --from=builder /opt/deepvariant/settings.sh .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/make_examples.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/call_variants.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/call_variants_slim.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/postprocess_variants.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/vcf_stats_report.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/show_examples.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/runtime_by_region_vis.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/multisample_make_examples.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/labeler/labeled_examples_to_vcf.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/make_examples_somatic.zip  .
COPY --from=builder /opt/deepvariant/bazel-out/k8-opt/bin/deepvariant/train.zip  .
COPY --from=builder /opt/deepvariant/scripts/run_deepvariant.py .
COPY --from=builder /opt/deepvariant/scripts/run_deepsomatic.py .

RUN ./run-prereq.sh

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 0 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 0

# Create shell wrappers for python zip files for easier use.
RUN \
  BASH_HEADER='#!/bin/bash' && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/make_examples.zip "$@"' > \
    /opt/deepvariant/bin/make_examples && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/call_variants.zip "$@"' > \
    /opt/deepvariant/bin/call_variants && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/call_variants_slim.zip "$@"' > \
    /opt/deepvariant/bin/call_variants_slim && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/postprocess_variants.zip "$@"' > \
    /opt/deepvariant/bin/postprocess_variants && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/vcf_stats_report.zip "$@"' > \
    /opt/deepvariant/bin/vcf_stats_report && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/show_examples.zip "$@"' > \
    /opt/deepvariant/bin/show_examples && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/runtime_by_region_vis.zip "$@"' > \
    /opt/deepvariant/bin/runtime_by_region_vis && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/multisample_make_examples.zip "$@"' > \
    /opt/deepvariant/bin/multisample_make_examples && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 -u /opt/deepvariant/bin/labeled_examples_to_vcf.zip "$@"' > \
    /opt/deepvariant/bin/labeled_examples_to_vcf && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 -u /opt/deepvariant/bin/make_examples_somatic.zip "$@"' > \
    /opt/deepvariant/bin/make_examples_somatic && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 -u /opt/deepvariant/bin/run_deepvariant.py "$@"' > \
    /opt/deepvariant/bin/run_deepvariant && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 -u /opt/deepvariant/bin/run_deepsomatic.py "$@"' > \
    /opt/deepvariant/bin/run_deepsomatic && \
  printf "%s\n%s\n" \
    "${BASH_HEADER}" \
    'python3 /opt/deepvariant/bin/train.zip "$@"' > \
    /opt/deepvariant/bin/train && \
  chmod +x /opt/deepvariant/bin/make_examples \
    /opt/deepvariant/bin/call_variants \
    /opt/deepvariant/bin/call_variants_slim \
    /opt/deepvariant/bin/postprocess_variants \
    /opt/deepvariant/bin/vcf_stats_report \
    /opt/deepvariant/bin/show_examples \
    /opt/deepvariant/bin/runtime_by_region_vis \
    /opt/deepvariant/bin/multisample_make_examples \
    /opt/deepvariant/bin/run_deepvariant \
    /opt/deepvariant/bin/run_deepsomatic \
    /opt/deepvariant/bin/labeled_examples_to_vcf \
    /opt/deepvariant/bin/make_examples_somatic \
    /opt/deepvariant/bin/train

# Copy models
WORKDIR /opt/models/hybrid_ont_904_illumina
COPY checkpoints/R9.4.1/${VERSION}/hyONT.ckpt/fingerprint.pb .
COPY checkpoints/R9.4.1/${VERSION}/hyONT.ckpt/saved_model.pb .
COPY checkpoints/R9.4.1/${VERSION}/hyONT.ckpt/example_info.json .
WORKDIR /opt/models/hybrid_ont_904_illumina/variables
COPY checkpoints/R9.4.1/${VERSION}/hyONT.ckpt/variables/variables.data-00000-of-00001 .
COPY checkpoints/R9.4.1/${VERSION}/hyONT.ckpt/variables/variables.index .
RUN chmod -R +r /opt/models/hybrid_ont_904_illumina/*

WORKDIR /opt/models/hybrid_ont_104_illumina
COPY checkpoints/R10.4.1/${VERSION}/hyONT.ckpt/fingerprint.pb .
COPY checkpoints/R10.4.1/${VERSION}/hyONT.ckpt/saved_model.pb .
COPY checkpoints/R10.4.1/${VERSION}/hyONT.ckpt/example_info.json .
WORKDIR /opt/models/hybrid_ont_104_illumina/variables
COPY checkpoints/R10.4.1/${VERSION}/hyONT.ckpt/variables/variables.data-00000-of-00001 .
COPY checkpoints/R10.4.1/${VERSION}/hyONT.ckpt/variables/variables.index .
RUN chmod -R +r /opt/models/hybrid_ont_104_illumina/*

WORKDIR /opt/deepvariant/bin
COPY scripts/run_honey_deepvariant.sh .
RUN chmod +x /opt/deepvariant/bin/run_honey_deepvariant.sh

WORKDIR /opt/deepvariant/resource
COPY resource/GRCh38_PAR.bed .

ENV PATH="${PATH}":/opt/conda/bin:/opt/conda/envs/bio/bin:/opt/deepvariant/bin

RUN apt-get -y update && \
  apt-get install -y parallel python3-pip && \
  PATH="${HOME}/.local/bin:$PATH" python3 -m pip install absl-py==0.13.0 && \
  apt-get clean autoclean && \
  apt-get autoremove -y --purge && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /opt/deepvariant

CMD ["/opt/deepvariant/bin/run_deepvariant", "--help"]
