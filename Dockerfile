# 使用官方轻量级 Miniconda3 基础镜像
FROM mambaorg/micromamba:1.5-alpine

# 将用户切换至 root 以便安装系统工具
USER root

# 安装基础生信命令行工具
RUN apk add --no-cache wget samtools fastp bash

# 使用 micromamba (极速版 conda) 从 bioconda 频道安装 snakemake 与依赖
# 这会直接下载预编译好的包，绝不会触发任何编译报错！
RUN micromamba install -y -n base -c conda-forge -c bioconda \
    snakemake \
    snakemake-storage-plugin-s3 \
    pandas \
    && micromamba clean --all --yes

# 激活基础环境路径
ENV PATH /opt/conda/bin:$PATH

# 创建并定义工作目录
WORKDIR /pipeline

# 复制项目代码
COPY Snakefile /pipeline/Snakefile
COPY run_pipeline.sh /pipeline/run_pipeline.sh
COPY scripts/ /pipeline/scripts/

# 赋予执行权限
RUN chmod +x /pipeline/run_pipeline.sh

ENTRYPOINT ["/pipeline/run_pipeline.sh"]

