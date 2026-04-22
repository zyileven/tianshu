# Tianshu 部署指南（镜像仓库）

将所有镜像推送到阿里云 ACR 镜像仓库，服务器只需 `docker pull` + `docker-compose up`。

---

## 一、系统要求

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

## 二、镜像列表

| 镜像 | 说明 | 大小 | 更新频率 |
|------|------|------|----------|
| `tianshu-backend` | 后端 API + Worker | ~16GB | 每次代码更新 |
| `tianshu-frontend` | 前端 Vue + Nginx | ~55MB | 前端更新时 |
| `tianshu-models` | AI 模型（独立镜像） | ~30GB | 模型更新时（很少） |
| `rustfs` | 对象存储 | ~240MB | 几乎不更新 |

---

## 三、开发机：配置仓库凭据

在项目根目录 `.env` 中配置（不要写到 `.env.example`，避免泄露）：

```bash
REGISTRY_PREFIX=registry.cn-chengdu.aliyuncs.com/tavan-ai
REGISTRY_USERNAME=your_username
REGISTRY_PASSWORD=your_password
```

---

## 四、开发机：构建镜像

```bash
bash deploy/docker/build.sh                # 构建所有镜像（backend + frontend）
bash deploy/docker/build.sh --backend-only  # 仅构建后端镜像
bash deploy/docker/build.sh --frontend-only # 仅构建前端镜像
bash deploy/docker/build.sh --models-only   # 仅构建模型镜像（首次需要）
```

构建完成后，本地应有以下镜像：

```bash
docker images | grep -E "tianshu|rustfs"
# tianshu-backend        latest    ...    ~16GB
# tianshu-frontend       latest    ...    ~55MB
# tianshu-models         latest    ...    ~30GB
# rustfs/rustfs          latest    ...    ~240MB
```

---

## 五、开发机：推送镜像

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

---

## 六、服务器：首次部署

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

### 验证部署

```bash
# 查看服务状态
docker-compose -f docker-compose.registry.yml ps

# API 健康检查
curl http://localhost:8000/health

# 浏览器访问
http://YOUR_SERVER_IP
```

默认账号：`admin` / `admin123`（**首次登录后立即修改密码**）

---

## 七、日常更新

### 代码更新

开发机：
```bash
bash deploy/docker/build.sh --backend-only
bash deploy/docker/push-to-registry.sh backend

# 也可以同时打版本标签，方便回滚
bash deploy/docker/push-to-registry.sh backend --tag v1.2.0
```

服务器：
```bash
cd /opt/tianshu
docker-compose -f docker-compose.registry.yml pull backend worker
docker-compose -f docker-compose.registry.yml up -d --no-deps backend worker scheduler mcp-server

# 如需回滚到指定版本，修改 .env 中 BACKEND_TAG=v1.2.0，然后重新 pull + up
```

### 前端更新

开发机：
```bash
bash deploy/docker/build.sh --frontend-only
bash deploy/docker/push-to-registry.sh frontend

# 带版本标签
bash deploy/docker/push-to-registry.sh frontend --tag v1.2.0
```

服务器：
```bash
cd /opt/tianshu
docker-compose -f docker-compose.registry.yml pull frontend
docker-compose -f docker-compose.registry.yml up -d --no-deps frontend
```

### 模型更新（很少需要）

开发机：
```bash
bash deploy/docker/build.sh --models-only
bash deploy/docker/push-to-registry.sh models
```

服务器：
```bash
cd /opt/tianshu
docker-compose -f docker-compose.registry.yml pull models-init
docker volume rm tianshu-models-shared
docker-compose -f docker-compose.registry.yml up -d
```

### 更新配置文件

修改了 `.env` 或 `docker-compose.registry.yml` 后：
```bash
cd /opt/tianshu
docker-compose -f docker-compose.registry.yml down
docker-compose -f docker-compose.registry.yml up -d
```

---

## 八、常用操作

### 查看服务状态

```bash
docker-compose -f docker-compose.registry.yml ps
```

### 查看日志

```bash
# 所有服务
docker-compose -f docker-compose.registry.yml logs -f

# 指定服务
docker-compose -f docker-compose.registry.yml logs -f backend
docker-compose -f docker-compose.registry.yml logs -f worker
```

### 重启服务

```bash
# 重启指定服务
docker-compose -f docker-compose.registry.yml restart backend worker

# 重启所有服务
docker-compose -f docker-compose.registry.yml restart
```

### 停止 / 启动

```bash
docker-compose -f docker-compose.registry.yml down
docker-compose -f docker-compose.registry.yml up -d
```

### 验证 GPU

```bash
docker-compose -f docker-compose.registry.yml exec worker nvidia-smi
```

---

## 九、故障排查

### 服务启动失败

```bash
# 查看详细错误
docker-compose -f docker-compose.registry.yml logs backend | tail -50
docker-compose -f docker-compose.registry.yml logs worker | tail -50

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
docker-compose -f docker-compose.registry.yml down
rm -rf data/db/*
docker-compose -f docker-compose.registry.yml up -d
```

---

## 十、环境配置说明

`.env` 关键配置项：

```bash
# 镜像仓库
REGISTRY_PREFIX=registry.cn-chengdu.aliyuncs.com/tavan-ai

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

## 十一、版本信息

- 平台：linux/amd64
- CUDA：12.6.2 + cuDNN
- Python：3.12
- PyTorch：2.6.0+cu126
- PaddlePaddle：3.2.0-gpu
- LibreOffice：24.8.x
