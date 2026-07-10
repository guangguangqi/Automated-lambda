FROM python:3.10-slim

# 1. 安装基础生信工具以及编译 C 语言依赖所需的系统环境
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    samtools \
    fastp \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 2. 升级 pip 并安装 Snakemake、S3 存储插件以及 pandas
# (增加 build-essential 后，datrie 的 C 代码就能顺利编译成功了)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir snakemake snakemake-storage-plugin-s3 pandas

# 3. 在镜像内部创建专门的管线工作目录
WORKDIR /pipeline

# 4. 将本地项目文件复制到 Docker 镜像内
COPY Snakefile /pipeline/Snakefile
COPY run_pipeline.sh /pipeline/run_pipeline.sh
COPY scripts/ /pipeline/scripts/

# 5. 赋予启动脚本执行权限
RUN chmod +x /pipeline/run_pipeline.sh

# 6. 定义容器启动时的默认入口
ENTRYPOINT ["/pipeline/run_pipeline.sh"]

