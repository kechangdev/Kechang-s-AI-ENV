# Kechang's AI ENV

- Docker Hub: 



## 快速使用

````bash
docker pull kechangdev/aienv
docker run -d \
		--rm \
		-v /path/to/project:/workspace \
		-e MAIN_PATH=$WORKSPACE/path/to/file.py \
		kechangdev/aienv
````

假设有项目位于 `/home/kechangdev/Projects/machine-learning-project`

文件目录如下：

````bash
machine-learning-project/
├── data/
│   ├── raw/                    
│   ├── processed/              
│   └── external/               
├── notebooks/                  
│   ├── exploratory-data-analysis.ipynb
│   └── model-evaluation.ipynb
├── src/                        
│   ├── __init__.py
│   ├── data/                   
│   │   ├── __init__.py
│   │   └── data_loader.py
│   ├── features/               
│   │   ├── __init__.py
│   │   └── feature_engineering.py
│   ├── models/                 
│   │   ├── __init__.py
│   │   ├── model.py
│   │   └── predict.py
│   ├── training/               
│   │   ├── __init__.py
│   │   └── train_model.py
│   └── evaluation/             
│       ├── __init__.py
│       └── evaluate_model.py
├── scripts/                    
│   ├── run_training.sh
│   ├── preprocess_data.sh
│   └── evaluate_model.sh
├── tests/                      
│   ├── __init__.py
│   ├── test_data_loader.py
│   ├── test_feature_engineering.py
│   ├── test_model.py
│   └── test_train_model.py
├── configs/                    
│   ├── config.yml
│   └── model_config.yml
├── requirements.txt            
├── environment.yml             
├── Dockerfile                  
├── README.md                   
├── setup.py                    
└── .gitignore                  
````

那么训练的时候应该创建 `container` ：

```bash
docker pull kechangdev/aienv
docker run -d \
		--rm \
		-v /home/kechangdev/Projects/machine-learning-project:/workspace \
		-e MAIN_PATH=src/training/train_model.py \
		-e UPDATE_ENV=1 \
		kechangdev/aienv
```



## 环境变量

- `MAIN_PATH`： 需要运行的 `.py` 文件的`相对路径`。

- `UPDATE_ENV`：如果为 `1` 则根据 `/workspace/environment.yml` 更新依赖环境。



# kechangdev/aienv-Dockerfile

本 `Dockerfile` 包含以下部分：

- 导入底镜像 `ubuntu:22.04`
- 设置时区
- 通过 `apt` 安装 `tzdata`、`vim`、`curl`、`wget`
- 通过  `apt` 安装 `SUMO` 并配置 `SUMO_HOME`
- 通过 `wget` 安装 `Anaconda` 并配置 `PATH`
- 创建 `update_env.sh` 、 `start_script.sh` 脚本
- 设定工作目录为 `/workspace`
- `COPY` `Dockerfile` 同目录下的 `environment.yml` 到 `/workspace/environment.yml`
- 通过 `update_env.sh` 脚本调用 `\workspace\environment.yml` 来配置 `conda` 的环境 `myenv`
- 设置 `container` 实例化后运行 `start_script.sh` 脚本



## Dockerfile

```dockerfile
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
```

## environment.yml

```yaml
name: myenv
channels:
  - defaults
dependencies:
  - python=3.8
  - pip
```



## 修改 `conda env` 环境

1. 在有网络的环境下，你可以在创建 `container` 的时候添加环境变量 `UPDATE_ENV=1` （当前目录需要包含 `environment.yml`）。

2. 在有网络的环境下，你可以通过修改 `container` 内 `/workspace/environment.yml` 的内容之后再在 `container` 的 `bash` 界面输入 `update_env` 来调用脚本实现环境修正。

3. 你可以先配置好 `environment.yml` 后创建 `Dockerfile` 并 `build` 你的 `image`。
