# 第一阶段：构建阶段
FROM ubuntu AS builder

# 设置非交互式环境变量，避免安装过程中的交互询问
ENV DEBIAN_FRONTEND=noninteractive

# 更新软件包列表并安装必要的依赖包
RUN apt-get update && \
    apt-get install -y build-essential pkg-config libssl-dev git-all protobuf-compiler cargo pkg-config libssl-dev curl && \
    # 清理 apt 缓存以减小镜像体积
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装 Rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

# 使 cargo 命令在当前 shell 会话中可用
ENV PATH="/root/.cargo/bin:${PATH}"

# 克隆 network-api 仓库
RUN git clone https://github.com/nexus-xyz/network-api

# 进入 network-api 目录
WORKDIR /network-api

# 切换到最新标签对应的提交
RUN git -c advice.detachedHead=false checkout "$(git rev-list --tags --max-count=1)"

# 进入 cli 目录并构建项目
WORKDIR /network-api/clients/cli

RUN cargo build --release

# 第二阶段：运行阶段
FROM ubuntu

# 从构建阶段复制可执行文件
COPY --from=builder /network-api /network-api

WORKDIR /network-api/clients/cli/target/release

# 更新软件包列表并安装必要的依赖包
RUN apt-get update && \
    apt-get install -y build-essential pkg-config libssl-dev git-all protobuf-compiler cargo curl && \
    # 清理 apt 缓存以减小镜像体积
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建 run_nexus_network.sh 文件并写入脚本内容
RUN echo '#!/bin/bash' > run_nexus_network.sh && \
    echo '# 首次运行' >> run_nexus_network.sh && \
    echo './nexus-network start --env beta' >> run_nexus_network.sh && \
    echo '# 循环执行' >> run_nexus_network.sh && \
    echo 'while true; do' >> run_nexus_network.sh && \
    echo '    echo y | ./nexus-network start --env beta' >> run_nexus_network.sh && \
    echo 'done' >> run_nexus_network.sh

# 为脚本添加可执行权限
RUN chmod +x run_nexus_network.sh

# 设置容器启动时执行的命令，即运行脚本
CMD ["./run_nexus_network.sh"]
