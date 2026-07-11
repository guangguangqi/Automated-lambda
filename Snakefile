# ==============================================================================
# Snakemake 8/9 Storage Plugin API
# ==============================================================================

storage:
    provider="s3"

SAMPLE = config["sample_id"]
BUCKET = config["bucket"].replace("s3://", "").rstrip("/")
R1_IN = config["r1_key"].lstrip("/")
R2_IN = config["r2_key"].lstrip("/")
S3_OUT = config["out_dir"].replace("s3://", "").strip("/")


rule all:
    input:
        storage.s3(
            f"s3://{S3_OUT}/qc/reports/{SAMPLE}_qc_verdict.txt"
        ),
        storage.s3(
            f"s3://{S3_OUT}/qc/reports/{SAMPLE}_fastp_summary.html"
        )


rule run_fastp:
    input:
        r1=storage.s3(
            f"s3://{BUCKET}/{R1_IN}"
        ),
        r2=storage.s3(
            f"s3://{BUCKET}/{R2_IN}"
        )

    output:
        r1_clean=storage.s3(
            f"s3://{S3_OUT}/clean_reads/{SAMPLE}_R1.clean.fastq.gz"
        ),
        r2_clean=storage.s3(
            f"s3://{S3_OUT}/clean_reads/{SAMPLE}_R2.clean.fastq.gz"
        ),
        json="logs/fastp/qc_report.json",
        html=storage.s3(
            f"s3://{S3_OUT}/qc/reports/{SAMPLE}_fastp_summary.html"
        )

    threads: 4

    shell:
        """
        mkdir -p logs/fastp

        fastp \
            --in1 {input.r1} \
            --in2 {input.r2} \
            --out1 {output.r1_clean} \
            --out2 {output.r2_clean} \
            --json {output.json} \
            --html {output.html} \
            --thread {threads}
        """



rule validate_qc_thresholds:
    input:
        json="logs/fastp/qc_report.json"

    output:
        verdict=storage.s3(
            f"s3://{S3_OUT}/qc/reports/{SAMPLE}_qc_verdict.txt"
        )

    shell:
        """
        python3 /pipeline/scripts/check_qc_thresholds.py \
            --json {input.json:q} \
            --min_q30 85.0 \
            --min_reads 5000000 \
            --output {output.verdict:q} \
            --soft-fail
        """
