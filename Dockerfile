FROM rocker/shiny:latest

# 安装系统依赖（ranger 可能需要编译工具）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 R 包
RUN install2.r --error --skipinstalled \
    shiny \
    survival \
    ranger

# 复制全部应用文件到 Shiny Server 目录
COPY . /srv/shiny-server/RSFpredictor/

# 确保文件权限正确
RUN chmod -R 755 /srv/shiny-server/RSFpredictor/

# 暴露端口
EXPOSE 3838

# 启动 Shiny Server
CMD ["/usr/bin/shiny-server"]
