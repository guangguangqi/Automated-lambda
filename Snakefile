# Force-load the official Snakemake S3 storage plugin
from snakemake.remote.S3 import RemoteProvider
S3 = RemoteProvider()

# Extract parameters injected via the --config flag from the entrypoint script
SAMPLE = config["sample_id"]
BUCKET = config["bucket"]
R1_IN  = config["r1_key"]
R2_IN  = config["r2_key"]
S3_OUT = config["out_dir"].rstrip('/')

rule all:
    input:
        # The final target reports we want pushed back up to our cloud S3 bucket
        S3.remote(f"{S3_OUT}/qc/reports/{SAMPLE}_qc_verdict.txt"),
        S3.remote(f"{S3_OUT}/qc/reports/{SAMPLE}_fastp_summary.html")

# RULE 1: Core Automated Data Quality Control & Filtering
rule run_fastp:
    input:
        # Snakemake automatically downloads these streaming files in the background
        r1 = S3.remote(f"{BUCKET}/{R1_IN}"),
        r2 = S3.remote(f"{BUCKET}/{R2_IN}")
    output:
        # Snakemake automatically caches files locally, processes them, 
        # and uploads the clean output files right back up to S3 upon rule success
        r1_clean = S3.remote(f"{S3_OUT}/clean_reads/{SAMPLE}_R1.clean.fastq.gz"),
        r2_clean = S3.remote(f"{S3_OUT}/clean_reads/{SAMPLE}_R2.clean.fastq.gz"),
        json     = "logs/fastp/qc_report.json", # Kept local temporarily
        html     = S3.remote(f"{S3_OUT}/qc/reports/{SAMPLE}_fastp_summary.html")
    threads: 4
    shell:
        """
        fastp \
            --in1 {input.r1} --in2 {input.r2} \
            --out1 {output.r1_clean} --out2 {output.r2_clean} \
            --json {output.json} --html {output.html} \
            --thread {threads}
        """

# RULE 2: Automated Quality Validation (Python Engine integration)
rule validate_qc_thresholds:
    input:
        json = "logs/fastp/qc_report.json"
    output:
        verdict = S3.remote(f"{S3_OUT}/qc/reports/{SAMPLE}_qc_verdict.txt")
    shell:
        """
        # Execute your localized python checker logic
        python3 /pipeline/scripts/check_qc_thresholds.py \
            --json {input.json} \
            --min_q30 85.0 \
            --min_reads 5000000 \
            --output {output.verdict}
        """

