FROM rocker/shiny:latest

# 安装系统依赖
RUN apt-get update \
    && apt-get install -y --no-install-recommends libcurl4-openssl-dev libssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装 R 包
RUN install2.r --error --skipinstalled shiny survival ranger

# 创建工作目录并复制应用文件
RUN mkdir -p /home/shiny/app
COPY . /home/shiny/app/

# 设置工作目录
WORKDIR /home/shiny/app

# 暴露 Shiny 默认端口
EXPOSE 3838

# 直接启动 Shiny 应用，监听所有网络接口
CMD ["R", "-e", "shiny::runApp('/home/shiny/app/app.R', port=3838, host='0.0.0.0')"]
