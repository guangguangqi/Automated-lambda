FROM python:3.10-slim

# 1. Install bioinformatics tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget samtools fastp && rm -rf /var/lib/apt/lists/*

# 2. Install Snakemake and required S3 cloud plugins
RUN pip install --no-cache-dir snakemake snakemake-storage-plugin-s3 pandas

# 3. Create a dedicated pipeline directory inside the image
WORKDIR /pipeline

# 4. COPY the pipeline code into the Docker image
COPY Snakefile /pipeline/Snakefile
COPY run_pipeline.sh /pipeline/run_pipeline.sh
COPY scripts/ /pipeline/scripts/

# 5. Make the shell entrypoint executable
RUN chmod +x /pipeline/run_pipeline.sh

# 6. Define the default action when the container starts
ENTRYPOINT ["/pipeline/run_pipeline.sh"]

