# ==============================================================================
# 🌟 全现代 Snakemake 存储插件官方标准语法（100% 杜绝 S3 未定义错误）
# ==============================================================================
# 1. 声明使用官方 S3 存储插件
storage:
    provider="s3"

# 2. 提取通过 AWS Batch 传进容器内部的精准 config 路径参数
SAMPLE = config["sample_id"]
BUCKET = config["bucket"]
R1_IN  = config["r1_key"]
R2_IN  = config["r2_key"]
S3_OUT = config["out_dir"].rstrip('/')

# 3. 终极总目标（定义管线最终要推回 S3 桶的成果物路径）
rule all:
    input:
        storage(f"s3://{S3_OUT}/qc/reports/{SAMPLE}_qc_verdict.txt"),
        storage(f"s3://{S3_OUT}/qc/reports/{SAMPLE}_fastp_summary.html")

# 4. RULE 1: 调用 fastp 进行双端序列质控过滤
rule run_fastp:
    input:
        # 容器开机后会利用 S3 插件在后台实现高并发流式下载
        r1 = storage(f"s3://{BUCKET}/{R1_IN}"),
        r2 = storage(f"s3://{BUCKET}/{R2_IN}")
    output:
        # 分析完成后，干净的 Fastq.gz 压缩包会自动一键闪传回您的 S3 桶
        r1_clean = storage(f"s3://{S3_OUT}/clean_reads/{SAMPLE}_R1.clean.fastq.gz"),
        r2_clean = storage(f"s3://{S3_OUT}/clean_reads/{SAMPLE}_R2.clean.fastq.gz"),
        json     = "logs/fastp/qc_report.json", # 保持容器本地临时缓存，用于 Rule 2
        html     = storage(f"s3://{S3_OUT}/qc/reports/{SAMPLE}_fastp_summary.html")
    threads: 4
    shell:
        """
        fastp \
            --in1 {input.r1} --in2 {input.r2} \
            --out1 {output.r1_clean} --out2 {output.r2_clean} \
            --json {output.json} --html {output.html} \
            --thread {threads}
        """

# 5. RULE 2: 质量自动化校验（拉起我们写好的 Python 自动化大闸）
rule validate_qc_thresholds:
    input:
        json = "logs/fastp/qc_report.json"
    output:
        verdict = storage(f"s3://{S3_OUT}/qc/reports/{SAMPLE}_qc_verdict.txt")
    shell:
        """
        python3 /pipeline/scripts/check_qc_thresholds.py \
            --json {input.json} \
            --min_q30 85.0 \
            --min_reads 5000000 \
            --output {output.verdict}
        """

