# Tianshu 打包发布操作文档

## 概览

整个发布流程分为 3 步：**构建** → **上传** → **部署**

```
开发机 (Mac/Linux)                    目标服务器 (GPU Linux)
┌─────────────────────┐               ┌─────────────────────────┐
│ 1. build-offline.sh │  ──rsync──→   │ 3. deploy-offline.sh    │
│    构建镜像+打包模型  │               │    加载镜像+启动服务      │
│                     │               │                         │
│ 2. upload-*.sh      │               │                         │
│    上传到服务器       │               │                         │
└─────────────────────┘               └─────────────────────────┘
```

---

## 一、全量构建（首次发布）

### 1.1 构建离线包

在开发机上执行：

```bash
bash scripts/build-offline.sh
```

**该脚本会自动完成：**
- 检测 Docker、Docker Compose、Python3 等依赖
- 下载模型到 `./models-offline/`（约 15GB，首次需要）
- 构建 Docker 镜像（backend + frontend）
- 导出镜像为 `.tar.gz` 文件
- 打包模型为 `models-offline.tar.gz`
- 复制配置文件（docker-compose.yml, .env.example, deploy-offline.sh）

**构建产物目录：** `./docker-images/`

```
docker-images/
├── tianshu-backend-amd64.tar.gz    # 后端镜像
├── tianshu-frontend-amd64.tar.gz   # 前端镜像
├── rustfs-amd64.tar.gz             # 对象存储镜像
├── models-offline.tar.gz           # 模型文件
├── docker-compose.yml              # 编排配置
├── .env.example                    # 环境变量模板
└── deploy-offline.sh               # 部署脚本
```

### 1.2 全量上传到服务器

```bash
bash scripts/upload-all-to-server.sh <用户名> <服务器IP> <部署路径>
```

**示例：**

```bash
bash scripts/upload-all-to-server.sh root 192.168.1.100 /opt/tianshu
```

**该脚本会：**
- 清理本地临时目录（models-offline/、models/、data/、logs/）
- 通过 `rsync` 上传所有文件到服务器
- 可选：上传完成后自动触发远程部署

### 1.3 在服务器上部署

SSH 登录服务器后执行：

```bash
cd /opt/tianshu   # 你的部署路径
bash deploy-offline.sh
```

**该脚本会自动完成：**
1. 检测 NVIDIA 驱动和 Container Toolkit
2. 加载 Docker 镜像（`docker load`）
3. 解压模型文件
4. 创建目录结构（data/uploads, data/output, data/db, logs/）
5. 生成 `.env` 配置（自动生成 JWT 密钥、检测服务器 IP）
6. 启动所有服务（`docker-compose up -d`）
7. 执行健康检查

**部署完成后的访问地址：**

| 服务 | 地址 |
|------|------|
| Web 界面 | `http://<服务器IP>` |
| API 接口 | `http://<服务器IP>:8000` |
| API 文档 | `http://<服务器IP>:8000/docs` |
| RustFS 控制台 | `http://<服务器IP>:9001` |

---

## 二、更新已运行的服务（重要）

> **`deploy-offline.sh` 不会自动停掉旧服务**，直接执行可能导致容器未使用新镜像。
> 更新时必须手动先停掉旧服务。

### 2.1 完整更新流程（服务器端）

SSH 登录服务器后，在部署目录执行：

```bash
cd /opt/tianshu   # 你的部署路径

# 第 1 步：停掉旧服务（数据不会丢失）
docker-compose -f docker-compose.offline.yml down

# 第 2 步：加载新镜像
docker load < tianshu-backend-amd64.tar.gz
docker load < tianshu-frontend-amd64.tar.gz
# rustfs 如无更新可跳过
# docker load < rustfs-amd64.tar.gz

# 第 3 步：重新启动
docker-compose -f docker-compose.offline.yml up -d
```

或者先 down 再直接跑部署脚本（效果一样，但会多做模型解压等检查）：

```bash
docker-compose -f docker-compose.offline.yml down
bash deploy-offline.sh
```

### 2.2 为什么不能直接执行 deploy-offline.sh？

- 脚本使用 `docker compose up -d` 启动服务，**不会自动执行 `down`**
- 镜像 tag 都是 `latest`，`docker load` 加载新镜像后，Docker Compose 不一定能感知到变化
- 如果不先 `down`，可能继续运行旧容器

### 2.3 关于数据安全

| 操作 | 数据是否保留 |
|------|-------------|
| `docker-compose down` | 保留（volume 挂载的 data/、logs/ 不受影响） |
| `docker-compose down -v` | **会删除 volume，不要用！** |
| `.env` 配置 | 保留（脚本检测到已有 `.env` 会跳过生成） |
| 模型文件 | 保留（已解压到 `models-offline/` 目录） |

### 2.4 模型解压的智能处理

`deploy-offline.sh` 会自动检测是否已存在 `models-offline/` 目录：

- **首次部署**：自动解压，无需确认
- **再次部署**：弹出交互提示，由你决定是否重新解压

```
[PROMPT] 模型文件是否有更新？需要重新解压吗？(y/N):
```

输入 `N` 或直接回车跳过解压，节省 5-10 分钟。输入 `y` 则重新解压覆盖。

---

## 三、增量更新（日常迭代）

当只需要更新某个组件时，使用增量上传脚本，无需全量重新打包。

### 3.1 重新构建需要更新的镜像

> **注意：** 目标服务器为 amd64 架构，构建时必须指定 `--platform linux/amd64`。
> 在 Mac (Apple Silicon) 上跨架构构建会通过 QEMU 模拟，速度较慢。
> 如果条件允许，建议直接在 GPU 服务器上构建（无需指定 `--platform`，原生 amd64）。

如果修改了后端代码，需要先重新构建后端镜像：

```bash
# 构建后端镜像（指定 amd64 架构）
DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64 -f backend/Dockerfile.offline -t tianshu-backend:latest .

# 导出镜像
docker save tianshu-backend:latest | gzip > docker-images/tianshu-backend-amd64.tar.gz
```

如果修改了前端代码：

```bash
docker buildx build --platform linux/amd64 -f frontend/Dockerfile -t tianshu-frontend:latest .
docker save tianshu-frontend:latest | gzip > docker-images/tianshu-frontend-amd64.tar.gz
```

### 3.2 增量上传

```bash
bash scripts/upload-spec-to-server.sh <用户名> <服务器IP> <部署路径> <组件>
```

**支持的组件选项：**

| 组件 | 说明 |
|------|------|
| `backend` | 仅上传后端镜像 |
| `frontend` | 仅上传前端镜像 |
| `rustfs` | 仅上传 RustFS 镜像 |
| `models` | 仅上传模型文件 |
| `config` | 仅上传配置文件 |

**示例：只更新后端**

```bash
bash scripts/upload-spec-to-server.sh root 192.168.1.100 /opt/tianshu backend
bash scripts/upload-spec-to-server.sh gpu 192.168.100.27 /home/gpu/tianshu2 backend
```

脚本会自动：
- 上传指定组件
- 在服务器上加载新镜像
- 提示是否重启相关服务

### 3.3 增量更新后在服务器上生效

`upload-spec-to-server.sh` 会提示是否自动重启，如果选了否，需要手动操作：

```bash
# SSH 到服务器
cd /opt/tianshu

# 停掉旧服务 → 启动新服务
docker-compose -f docker-compose.offline.yml down
docker-compose -f docker-compose.offline.yml up -d
```

---

## 四、本地 CPU 开发（Mac）

适用于 Mac 本地开发调试，无需 GPU。

### 4.1 构建 CPU 镜像

```bash
bash scripts/build-local-cpu.sh
```

需要提供离线模型目录路径（`models-offline/`）。

### 4.2 启动本地服务

```bash
bash scripts/start-local-cpu.sh
```

**该脚本会：**
- 检查 Docker 和 CPU 镜像
- 生成/检查 `.env.cpu` 配置
- 使用 `docker-compose.cpu.yml` 启动服务
- 执行健康检查

**本地开发特点：**
- 通过 Rosetta 2 运行 amd64 镜像
- 源码目录挂载，支持热重载
- CPU 模式，处理速度较慢但功能完整

---

## 五、常用运维命令

### 查看服务状态

```bash
docker-compose ps
docker-compose logs -f          # 查看所有日志
docker-compose logs -f worker   # 查看 worker 日志
docker-compose logs -f backend  # 查看后端日志
```

### 重启服务

```bash
docker-compose restart          # 重启所有服务
docker-compose restart worker   # 只重启 worker
docker-compose restart backend  # 只重启后端
```

### 停止/启动

```bash
docker-compose down             # 停止所有服务
docker-compose up -d            # 后台启动所有服务
```

### GPU 检查

```bash
# 检查宿主机 GPU
nvidia-smi

# 检查容器内 GPU
docker exec tianshu-worker nvidia-smi
docker exec tianshu-worker python -c "import torch; print(torch.cuda.is_available())"
```

### 健康检查

```bash
curl http://localhost:8000/api/v1/health
```

---

## 六、关键配置说明

`.env` 文件中的重要配置项：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `GPU_COUNT` | GPU 数量 | `1` |
| `CUDA_VISIBLE_DEVICES` | 使用的 GPU 编号 | `0` |
| `WORKER_GPUS` | 每 GPU 的 worker 数 | `1` |
| `WORKER_MEMORY_LIMIT` | Worker 内存上限 | `32g` |
| `MAX_BATCH_SIZE` | 批处理大小 | `4` |
| `WORKER_TIMEOUT` | Worker 超时时间 | `300` |
| `MAX_FILE_SIZE` | 最大文件大小(MB) | `100` |
| `MODEL_DOWNLOAD_SOURCE` | 模型下载源 | `auto` |
| `RUSTFS_ENABLED` | 是否启用对象存储 | `true` |
| `REDIS_ENABLED` | 是否启用 Redis | `false` |

---

## 七、故障排查

### 镜像加载失败

```bash
# 检查磁盘空间
df -h
# 手动加载镜像
docker load < tianshu-backend-amd64.tar.gz
```

### Worker 启动失败

```bash
# 查看 worker 日志
docker-compose logs worker
# 检查模型是否正确挂载
docker exec tianshu-worker ls -la /models-external/
```

### GPU 不可用

```bash
# 确认 NVIDIA Container Toolkit 已安装
docker run --rm --gpus all nvidia/cuda:12.6.2-base-ubuntu24.04 nvidia-smi
```

### 服务无法访问

```bash
# 检查端口占用
netstat -tlnp | grep -E '80|8000|8001|9000'
# 检查容器状态
docker-compose ps
```
