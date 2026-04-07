# Tianshu 离线部署指南

## 部署包内容

构建包会将文件输出在 docker-images 文件中，包含以下内容：

| 文件 | 说明 | 大小 |
|------|------|------|
| `tianshu-backend-amd64.tar.gz` | 后端完整镜像（首次全量部署用） | ~10GB |
| `tianshu-backend-deps-amd64.tar.gz` | 后端依赖层镜像（切换增量流程时用一次） | ~10GB |
| `tianshu-frontend-amd64.tar.gz` | 前端镜像 | ~22MB |
| `rustfs-amd64.tar.gz` | 对象存储镜像 | ~78MB |
| `models-offline.tar.gz` | AI 模型包 | ~14GB |
| `docker-compose.yml` | 服务编排配置 | - |
| `.env.example` | 环境变量模板 | - |
| `deploy-offline.sh` | 首次部署脚本 | - |

---

## 系统要求

### 硬件
- CPU：x86_64，4 核心以上
- 内存：16GB 以上（推荐 32GB）
- GPU：NVIDIA，显存 8GB 以上（推荐 16GB+），Compute Capability 7.0+
- 磁盘：系统盘 50GB+，数据盘 100GB+

### 软件
- OS：Linux（Ubuntu 20.04/22.04/24.04，CentOS 8+）
- Docker 20.10+
- Docker Compose 2.0+
- NVIDIA 驱动 535+
- NVIDIA Container Toolkit

### 验证 GPU 环境
```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi
```

---

## 镜像架构说明

后端镜像分为两层，支持快速增量更新：

```
tianshu-backend-deps:latest  ← 依赖层（~10GB，只在依赖变更时重建）
        ↓ FROM
tianshu-backend:latest       ← 完整镜像（deps 层 + 代码层）
```

每次代码更新只需上传几 MB 的代码包，在服务器上基于已有的 deps 层重新 build，无需重传 10GB 镜像。

---

## 一、首次部署

### 1. 开发机：构建所有镜像

```bash
# 全量构建（约 60-90 分钟）
bash deploy/docker/build-offline.sh
```

输出目录：`docker-images/`，包含所有镜像和配置文件。

### 2. 开发机：上传到服务器

```bash
bash deploy/docker/upload-all-to-server.sh root YOUR_SERVER_IP /opt/tianshu 
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
```

### 3. 服务器：执行部署

```bash
ssh root@YOUR_SERVER_IP
cd /opt/tianshu
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
bash deploy-offline.sh
```

脚本自动完成：
1. 检查 GPU 环境
2. 加载所有 Docker 镜像（5-10 分钟）
3. 解压模型文件（5-10 分钟）
4. 创建目录结构
5. 生成 `.env` 配置文件
6. 启动所有服务

### 4. 验证部署

```bash
# 查看服务状态
docker-compose ps

# API 健康检查
curl http://localhost:8000/health

# 浏览器访问
http://YOUR_SERVER_IP
```

默认账号：`admin` / `admin123`（**首次登录后立即修改密码**）

---

## 二、切换到增量更新流程（一次性操作）

> 已完成首次部署后，执行此步骤即可切换到快速增量更新模式。只需做一次。

### 1. 开发机：构建依赖层镜像

```bash
# 本地有缓存时很快（几分钟）
bash deploy/docker/build-offline.sh --deps-only
```

输出：`docker-images/tianshu-backend-deps-amd64.tar.gz`

### 2. 开发机：上传到服务器

```bash
bash deploy/docker/upload-spec-to-server.sh root YOUR_SERVER_IP /opt/tianshu backend-deps
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
```

### 3. 服务器：加载镜像

```bash
cd /opt/tianshu
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
sudo docker load < tianshu-backend-deps-amd64.tar.gz
rm -f tianshu-backend-deps-amd64.tar.gz
```

加载过程不影响正在运行的服务（约 5-10 分钟）。完成后服务器上有了 `tianshu-backend-deps:latest`，后续代码更新只需几 MB。

---

## 三、日常代码增量更新（推荐）

> 前提：已完成上方"切换到增量更新流程"步骤。

每次修改代码后：

### 1. 开发机：打包代码

```bash
bash deploy/docker/build-offline.sh --code-only
```

耗时约 10 秒，输出：`docker-images/tianshu-backend-code-update.tar.gz`（< 10MB）

### 2. 开发机：上传到服务器

```bash
bash deploy/docker/upload-spec-to-server.sh root YOUR_SERVER_IP /opt/tianshu backend-code
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
```

### 3. 服务器：构建镜像并重启

在 `/opt/tianshu` 下执行：

```bash
rm -rf /tmp/tianshu-update && mkdir -p /tmp/tianshu-update
tar xzf tianshu-backend-code-update.tar.gz -C /tmp/tianshu-update/
sudo docker build -f /tmp/tianshu-update/Dockerfile.code -t tianshu-backend:latest /tmp/tianshu-update/
sudo docker-compose up -d --no-deps backend worker
rm -rf /tmp/tianshu-update tianshu-backend-code-update.tar.gz
```

**全程约 1-3 分钟**（含短暂服务重启停机）。

---

## 四、其他组件更新

### 更新前端

开发机：
```bash
bash deploy/docker/build-offline.sh
bash deploy/docker/upload-spec-to-server.sh root YOUR_SERVER_IP /opt/tianshu frontend
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
```

服务器：
```bash
cd /opt/tianshu
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
sudo docker load < tianshu-frontend-amd64.tar.gz
sudo docker-compose restart frontend
rm -f tianshu-frontend-amd64.tar.gz
```

### 更新配置文件

开发机：
```bash
bash deploy/docker/upload-spec-to-server.sh root YOUR_SERVER_IP /opt/tianshu config
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
```

服务器（修改了 `.env` 或 `docker-compose.yml` 时）：
```bash
cd /opt/tianshu
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
sudo docker-compose down && sudo docker-compose up -d
```

### 更新模型文件

开发机：
```bash
bash deploy/docker/upload-spec-to-server.sh root YOUR_SERVER_IP /opt/tianshu models
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
```

服务器：
```bash
cd /opt/tianshu
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
rm -rf models-offline
tar xzf models-offline.tar.gz
sudo docker-compose exec -T worker rm -f /root/.cache/.models_initialized
sudo docker-compose restart worker
```

### 依赖变更时的全量更新

修改了 `pyproject.toml` 或 `requirements.txt` 时：

开发机：
```bash
bash deploy/docker/build-offline.sh
bash deploy/docker/upload-spec-to-server.sh root YOUR_SERVER_IP /opt/tianshu backend
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定

# 同时更新 deps 层供后续增量使用
bash deploy/docker/build-offline.sh --deps-only
bash deploy/docker/upload-spec-to-server.sh root YOUR_SERVER_IP /opt/tianshu backend-deps
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
```

服务器：
```bash
cd /opt/tianshu
# ⚠️注意：这个/opt/tianshu地址部署时根据实际情况来定
sudo docker load < tianshu-backend-amd64.tar.gz
sudo docker-compose up -d --no-deps backend worker
rm -f tianshu-backend-amd64.tar.gz

# 更新 deps 层
sudo docker load < tianshu-backend-deps-amd64.tar.gz
rm -f tianshu-backend-deps-amd64.tar.gz
```

---

## 五、常用操作

### 查看服务状态

```bash
docker-compose ps
```

### 查看日志

```bash
# 所有服务
docker-compose logs -f

# 指定服务
docker-compose logs -f backend
docker-compose logs -f worker
```

### 重启服务

```bash
# 重启指定服务
docker-compose restart backend worker

# 重启所有服务
docker-compose restart
```

### 停止 / 启动

```bash
docker-compose down
docker-compose up -d
```

### 验证 GPU

```bash
docker-compose exec worker nvidia-smi
```

---

## 六、故障排查

### 服务启动失败

```bash
# 查看详细错误
docker-compose logs backend | tail -50
docker-compose logs worker | tail -50

# 检查端口占用
netstat -tuln | grep -E "(8000|8001|9000)"

# 检查磁盘空间
df -h
```

### GPU 不可用

```bash
# 检查驱动
nvidia-smi

# 检查 Container Toolkit
docker run --rm --gpus all nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi

# 重启 Docker
sudo systemctl restart docker
```

### 对象存储访问失败

```bash
# 检查 RustFS 配置
grep RUSTFS .env

# 测试连通性
curl http://localhost:9000/health
```

### 数据库异常

```bash
# 重置数据库（会清空所有数据，谨慎操作）
docker-compose down
rm -rf data/db/*
docker-compose up -d
```

---

## 七、环境配置说明

`.env` 关键配置项：

```bash
# JWT 密钥（必须修改）
JWT_SECRET_KEY=your-secret-key-change-in-production

# 对象存储公网访问地址（改为实际服务器 IP）
RUSTFS_PUBLIC_URL=http://YOUR_SERVER_IP:9000

# GPU 配置
NVIDIA_VISIBLE_DEVICES=all
NVIDIA_DRIVER_CAPABILITIES=compute,utility
```

生成 JWT 密钥：
```bash
openssl rand -hex 32
```

---

## 八、镜像仓库部署（推荐）

> 将所有镜像（含模型）推送到阿里云 ACR 镜像仓库，服务器只需 `docker pull` + `docker-compose up`，无需手动传输文件。

### 优势

| | 离线包部署 | 镜像仓库部署 |
|--|--|--|
| 传输方式 | scp 上传 tar.gz | docker pull（断点续传） |
| 模型更新 | 重新上传 13GB | docker pull 增量拉取 |
| 代码更新 | 打包 + 上传 + 服务器 build | docker pull + restart |
| 多机部署 | 每台都要传文件 | 每台直接 pull |

### 镜像列表

| 镜像 | 说明 | 大小 | 更新频率 |
|------|------|------|----------|
| `tianshu-backend` | 后端 API + Worker | ~16GB | 每次代码更新 |
| `tianshu-frontend` | 前端 Vue + Nginx | ~55MB | 前端更新时 |
| `tianshu-models` | AI 模型（独立镜像） | ~30GB | 模型更新时（很少） |
| `rustfs` | 对象存储 | ~240MB | 几乎不更新 |

### 1. 开发机：配置仓库凭据

在项目根目录 `.env` 中配置（不要写到 `.env.example`，避免泄露）：

```bash
REGISTRY_PREFIX=registry.cn-chengdu.aliyuncs.com/tavan-ai
REGISTRY_USERNAME=your_username
REGISTRY_PASSWORD=your_password
```

### 2. 开发机：构建镜像

构建和推送是**分开的两步操作**。

```bash
# 构建后端镜像（首次约 60-90 分钟）
bash deploy/docker/build-offline.sh

# 构建模型镜像（首次需要，约 10-20 分钟）
bash deploy/docker/build-offline.sh --models-only
```

构建完成后，本地应有以下镜像：

```bash
docker images | grep -E "tianshu|rustfs"
# tianshu-backend        latest    ...    ~16GB
# tianshu-frontend       latest    ...    ~55MB
# tianshu-models         latest    ...    ~30GB
# rustfs/rustfs          latest    ...    ~240MB
```

### 3. 开发机：逐个推送镜像

推送脚本自动从 `.env` 读取仓库账号密码并登录，每次只推送一个镜像：

```bash
# 推送后端
bash deploy/docker/push-to-registry.sh backend

# 推送前端
bash deploy/docker/push-to-registry.sh frontend

# 推送模型（首次，约 30GB）
bash deploy/docker/push-to-registry.sh models

# 推送 RustFS
bash deploy/docker/push-to-registry.sh rustfs

# 也可以指定版本标签
bash deploy/docker/push-to-registry.sh backend --tag v1.0.0
```

### 4. 服务器：首次部署

```bash
# 登录镜像仓库
docker login registry.cn-chengdu.aliyuncs.com

# 创建部署目录
mkdir -p /opt/tianshu && cd /opt/tianshu

# 从开发机复制配置文件到此目录:
#   - docker-compose.registry.yml
#   - .env.example
#   - mcp_config.example.json
cp .env.example .env

# 编辑 .env，设置:
#   REGISTRY_PREFIX=registry.cn-chengdu.aliyuncs.com/tavan-ai
#   RUSTFS_PUBLIC_URL=http://YOUR_SERVER_IP:9000
#   JWT_SECRET_KEY=（用 openssl rand -hex 32 生成）

# 创建数据目录
mkdir -p data/{uploads,output,db} logs/{backend,worker,mcp,scheduler} models

# 启动（首次会自动 pull 所有镜像 + 复制模型到共享卷）
docker-compose -f docker-compose.registry.yml up -d
```

首次启动时 `models-init` 服务会将模型从镜像复制到共享卷（约 5-10 分钟），
backend 和 worker 会等待其完成后再启动。后续重启不会重复复制。

### 5. 日常更新

**代码更新（开发机）：**

```bash
# 重新构建后端镜像
bash deploy/docker/build-offline.sh

# 推送
bash deploy/docker/push-to-registry.sh backend
```

**代码更新（服务器）：**

```bash
cd /opt/tianshu
docker-compose -f docker-compose.registry.yml pull backend worker
docker-compose -f docker-compose.registry.yml up -d --no-deps backend worker scheduler mcp-server
```

**前端更新（同理）：**

```bash
# 开发机
bash deploy/docker/push-to-registry.sh frontend

# 服务器
docker-compose -f docker-compose.registry.yml pull frontend
docker-compose -f docker-compose.registry.yml up -d --no-deps frontend
```

**模型更新（很少需要）：**

```bash
# 开发机
bash deploy/docker/build-offline.sh --models-only
bash deploy/docker/push-to-registry.sh models

# 服务器：需要删除旧的共享卷，重新初始化
docker-compose -f docker-compose.registry.yml pull models-init
docker volume rm tianshu-models-shared
docker-compose -f docker-compose.registry.yml up -d
```

---

## 九、版本信息

- 平台：linux/amd64
- CUDA：12.6.2 + cuDNN
- Python：3.12
- PyTorch：2.6.0+cu126
- PaddlePaddle：3.2.0-gpu
- LibreOffice：24.8.x
