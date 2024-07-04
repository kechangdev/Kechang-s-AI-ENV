FROM ubuntu:22.04
ENV TZ=Asia/Shanghai
RUN apt-get update && apt-get install -y \
    tzdata \
    vim \
    curl \
    wget \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && dpkg-reconfigure --frontend noninteractive tzdata

# SUMO
RUN apt-get install -y software-properties-common \
    && add-apt-repository ppa:sumo/stable \
    && apt-get update \
    && apt-get install -y sumo sumo-tools sumo-doc
ENV SUMO_HOME /usr/share/sumo

# Anaconda
RUN wget --quiet https://repo.anaconda.com/archive/Anaconda3-2024.06-1-Linux-x86_64.sh -O ~/anaconda.sh \
    && /bin/bash ~/anaconda.sh -b -p /opt/anaconda \
    && rm ~/anaconda.sh
ENV PATH /opt/anaconda/bin:$PATH

# update_env.sh
RUN echo '#!/bin/bash\n\
\n\
# 环境名称\n\
ENV_NAME="myenv"\n\
\n\
# 检查环境是否存在并删除\n\
if conda info --envs | grep -q "$ENV_NAME"; then\n\
    echo "环境已存在，正在删除..."\n\
    conda env remove -n "$ENV_NAME"\n\
    echo "环境已删除。"\n\
fi\n\
\n\
# 创建新的conda环境，并强制名称为myenv\n\
echo "正在创建新的conda环境..."\n\
conda env create -n "$ENV_NAME" --file /workspace/environment.yml\n\
\n\
# 清理conda缓存\n\
echo "清理conda缓存..."\n\
conda clean -a\n\
\n\
echo "环境设置完成。"' > /usr/local/bin/update_env && chmod +x /usr/local/bin/update_env

# start_script.sh
RUN echo '#!/bin/bash\n\
\n\
# 初始化conda\n\
source /opt/anaconda/etc/profile.d/conda.sh\n\
\n\
# 如果环境变量 UPDATE_ENV 设置为 1，则调用 update_env.sh\n\
if [ "$UPDATE_ENV" == "1" ]; then\n\
    echo "更新环境..."\n\
    /usr/local/bin/update_env\n\
fi\n\
\n\
# 激活conda环境\n\
conda activate myenv\n\
\n\
# 检查环境变量MAIN_PATH是否设置\n\
if [ -z "$MAIN_PATH" ]; then\n\
    echo "错误: MAIN_PATH环境变量未设置"\n\
    exit 1\n\
fi\n\
\n\
# 确保环境变量已更新\n\
export PATH=/opt/anaconda/envs/myenv/bin:$PATH\n\
\n\
# 运行指定的Python脚本\n\
python3 "/workspace/$MAIN_PATH" -c "/workspace/config.yml"' > /usr/local/bin/start_script.sh && chmod +x /usr/local/bin/start_script.sh

WORKDIR /workspace
COPY environment.yml /workspace/environment.yml

# Create conda env
RUN /usr/local/bin/update_env

# Active conda env
RUN echo "source /opt/anaconda/etc/profile.d/conda.sh && conda activate myenv" > /root/.bashrc
ENV PATH /opt/anaconda/envs/myenv/bin:$PATH

ENTRYPOINT ["/usr/local/bin/start_script.sh"]
