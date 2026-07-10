# Use the Debian-based micromamba image (avoiding Alpine compatibility issues)
FROM mambaorg/micromamba:1.5-debian-slim

USER root

# 1. Install standard system tools via apt-get
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    samtools \
    fastp \
    bash \
    && rm -rf /var/lib/apt/lists/*

# 2. Use micromamba to install snakemake ecosystem (Pre-compiled, no compile errors!)
RUN micromamba install -y -n base -c conda-forge -c bioconda \
    snakemake \
    snakemake-storage-plugin-s3 \
    pandas \
    && micromamba clean --all --yes

# 3. Modern environment path formatting (Fixes the Docker format warning)
ENV PATH="/opt/conda/bin:${PATH}"

# 4. Define and copy pipeline assets
WORKDIR /pipeline

COPY Snakefile /pipeline/Snakefile
COPY run_pipeline.sh /pipeline/run_pipeline.sh
COPY scripts/ /pipeline/scripts/

RUN chmod +x /pipeline/run_pipeline.sh

ENTRYPOINT ["/pipeline/run_pipeline.sh"]
