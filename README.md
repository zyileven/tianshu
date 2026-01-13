<div align="center">

# Tianshu 天枢

**企业级 AI 数据预处理平台**

支持文档、图片、音频等多模态数据处理 | GPU 加速 | MCP 协议

结合 Vue 3 前端 + FastAPI 后端 + LitServe GPU负载均衡

<p>
  <a href="https://github.com/magicyuan876/mineru-tianshu/stargazers">
    <img src="https://img.shields.io/github/stars/magicyuan876/mineru-tianshu?style=for-the-badge&logo=github&color=yellow" alt="Stars"/>
  </a>
  <a href="https://github.com/magicyuan876/mineru-tianshu/network/members">
    <img src="https://img.shields.io/github/forks/magicyuan876/mineru-tianshu?style=for-the-badge&logo=github&color=blue" alt="Forks"/>
  </a>
  <a href="https://github.com/magicyuan876/mineru-tianshu/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-Apache%202.0-green?style=for-the-badge" alt="License"/>
  </a>
</p>

<p>
  <img src="https://img.shields.io/badge/Python-3.8+-blue?logo=python&logoColor=white" alt="Python"/>
  <img src="https://img.shields.io/badge/Vue-3.x-green?logo=vue.js&logoColor=white" alt="Vue"/>
  <img src="https://img.shields.io/badge/FastAPI-0.115+-teal?logo=fastapi&logoColor=white" alt="FastAPI"/>
  <img src="https://img.shields.io/badge/CUDA-Supported-76B900?logo=nvidia&logoColor=white" alt="CUDA"/>
  <img src="https://img.shields.io/badge/MCP-Supported-orange" alt="MCP"/>
</p>

[![Verified on MseeP](https://mseep.ai/badge.svg)](https://mseep.ai/app/819ff68b-5154-4717-9361-7db787d5a2f8)

[English](./README_EN.md) | 简体中文

<p>
  <a href="https://github.com/magicyuan876/mineru-tianshu">
    <img src="https://img.shields.io/badge/⭐_Star-项目-yellow?style=for-the-badge&logo=github" alt="Star"/>
  </a>
</p>

**如果这个项目对你有帮助，请点击右上角 ⭐ Star 支持一下，这是对开发者最大的鼓励！**

</div>

---

## 📝 最新更新

### 2025-12-10 ⚡ 大文件并行处理

- ✅ **PDF 自动拆分功能**：超过阈值（默认 500 页）的 PDF 自动拆分为多个子任务并行处理
  - 可配置的分块大小（默认 500 页/块），显著提升大文件处理速度
  - 实现父子任务系统：自动管理子任务状态并在完成后合并结果
  - 智能结果合并：保留原始页码信息，按序合并 Markdown 和 JSON 输出
  - 处理时间可缩短 40-60%（取决于硬件配置）
  - **异步拆分**：拆分操作在 Worker 中进行，API 接口秒级响应
- ✅ **PDF 拆分配置**（`.env` 新增）
  - `PDF_SPLIT_ENABLED`: 是否启用自动拆分（默认 `true`）
  - `PDF_SPLIT_THRESHOLD_PAGES`: 拆分阈值页数（默认 `500`）
  - `PDF_SPLIT_CHUNK_SIZE`: 每个子任务处理页数（默认 `500`）
- ✅ **Worker 内存管理**
  - `WORKER_MEMORY_LIMIT`: 容器硬内存限制（默认 `16G`）
  - `WORKER_MEMORY_RESERVATION`: 内存软限制/预留（默认 `8G`）

### 2025-12-05 🗄️ RustFS 对象存储集成

- ✅ **RustFS 对象存储**：所有解析结果的图片自动上传到对象存储
  - S3 兼容 API，基于 minio-py 实现
  - 批量上传图片，自动生成公开访问 URL
  - 短且唯一的文件名生成（时间戳 Base62 + NanoID）
  - 按日期自动分组（YYYYMMDD/文件名.ext）
  - Markdown/JSON 中的图片路径自动替换为对象存储 URL
  - Docker Compose 一键部署 RustFS 服务
  - 需配置 `RUSTFS_PUBLIC_URL` 环境变量（外部可访问地址）
- ✅ **输出标准化优化**：改进图片路径处理，统一使用对象存储 URL
- ✅ **配置简化**：精简 `.env.example` 配置文件，移除冗余选项

### 2025-11-12 📦 代码优化与文档整理

- ✅ **输出标准化**：统一 Markdown/JSON 输出格式，优化图片路径处理
- ✅ **文档精简**：精简 README 文档，移除冗余说明文件，保持项目整洁
- ✅ **代码质量**：优化错误处理，改进日志输出，提升系统稳定性

### 2025-10-30 🐳 Docker 部署 + 企业级认证系统

- ✅ **Docker 容器化部署支持**
  - **一键部署**：`make setup` 或运行部署脚本即可完成全栈部署
  - **多阶段构建**：优化镜像体积，分离依赖层和应用层
  - **GPU 支持**：NVIDIA CUDA 12.6 + Container Toolkit 集成
  - **服务编排**：前端、后端、Worker、MCP 完整编排（docker-compose）
  - **开发友好**：支持热重载、远程调试（debugpy）、实时日志
  - **生产就绪**：健康检查、数据持久化、零停机部署、资源限制
  - **跨平台脚本**：
    - Linux/Mac: `scripts/docker-setup.sh` 或 `Makefile`
    - Windows: `scripts/docker-setup.bat`
  - **完整文档**：`scripts/DOCKER_QUICK_START.txt`、`scripts/docker-commands.sh`
  - 详见：Docker 配置文件（`docker-compose.yml`、`backend/Dockerfile`、`frontend/Dockerfile`）

- ✅ **企业级用户认证与授权系统**
  - **JWT 认证**：安全的 Token 认证机制，支持 Access Token 和 Refresh Token
  - **用户数据隔离**：每个用户只能访问和管理自己的任务数据
  - **角色权限**：管理员（admin）和普通用户（user）角色
  - **API Key 管理**：用户可自助生成和管理 API 密钥，用于第三方集成
  - **用户管理**：管理员可管理所有用户、重置密码、启用/禁用账户
  - **SSO 预留接口**：支持 OIDC 和 SAML 2.0 单点登录（可选配置）
  - **前端集成**：登录/注册页面、用户中心、权限路由守卫
  - **数据库迁移**：自动为现有数据创建默认用户
  - 详见：`backend/auth/` 目录

### 2025-10-29 🧬 生物信息学格式支持

- ✅ **新增插件化格式引擎系统**
  - 支持专业领域文档格式的解析和结构化
  - 统一的引擎接口，易于扩展新格式
  - 为 RAG 应用提供 Markdown 和 JSON 双格式输出

- ✅ **生物信息学格式引擎**
  - **FASTA 格式**：DNA/RNA/蛋白质序列解析
    - 序列统计（数量、长度、平均值）
    - 碱基组成分析（A/T/G/C 比例）
    - 序列类型自动检测（DNA/RNA/蛋白质）
  - **GenBank 格式**：NCBI 基因序列注释格式
    - 完整的注释信息提取
    - 特征类型统计（gene/CDS/mRNA 等）
    - GC 含量计算和生物物种信息
  - 支持 BioPython 或内置解析器（可选依赖）
  - 详见：`backend/format_engines/README.md`

### 2025-10-27 🎨 水印去除支持（🧪 实验性）

- ✅ **智能水印检测与去除**
  - YOLO11x 专用检测模型 + LaMa 高质量修复
  - 支持图片（PNG/JPG/JPEG 等）和 PDF（可编辑/扫描件）
  - 前端可调参数：检测置信度、去除范围
  - 自动保存调试文件（检测可视化、掩码等）
  - 轻量模型，处理速度快，显存占用低

> **⚠️ 实验性功能**：某些特殊水印可能效果不佳，建议先小范围测试。  
> 📖 **详细说明**：[水印去除优化指南](backend/remove_watermark/README.md)

### 2025-10-24 🎬 视频处理支持

- ✅ **新增视频处理引擎**
  - 支持 MP4、AVI、MKV、MOV、WebM 等主流视频格式
  - **音频转写**：从视频中提取音频并转写为文字（基于 FFmpeg + SenseVoice）
  - **关键帧 OCR（🧪 实验性）**：自动提取视频关键帧并进行 OCR 识别
    - 场景检测：基于帧差异的自适应场景变化检测
    - 质量过滤：拉普拉斯方差 + 亮度评估
    - 图像去重：感知哈希（pHash）+ 汉明距离
    - 文本去重：编辑距离算法避免重复内容
    - 支持 PaddleOCR-VL 引擎
  - 支持多语言识别、说话人识别、情感识别
  - 输出带时间戳的文字稿（JSON 和 Markdown 格式）
  - 详见：`backend/video_engines/README.md`

### 2025-10-23 🎙️ 音频处理引擎

- ✅ **新增 SenseVoice 音频识别引擎**
  - 支持多语言识别（中文/英文/日文/韩文/粤语）
  - 内置说话人识别（Speaker Diarization）
  - 情感识别（中性/开心/生气/悲伤）
  - 输出 JSON 和 Markdown 格式
  - 详见：`backend/audio_engines/README.md`

### 2025-10-23 ✨

**🎯 支持内容结构化 JSON 格式输出**

- MinerU (pipeline) 和 PaddleOCR-VL 引擎现在支持输出结构化的 JSON 格式
- JSON 输出包含完整的文档内容结构信息（页面、段落、表格等）
- 用户可在任务详情页面切换查看 Markdown 或 JSON 格式
- 前端提供交互式 JSON 查看器，支持展开/收起、复制、下载等功能

**🎉 新增 PaddleOCR-VL 多语言 OCR 引擎**

- 支持 109+ 语言自动识别，无需手动指定语言
- 文档方向分类、文本图像矫正、版面区域检测等增强功能
- 原生 PDF 多页文档支持，模型自动下载管理
- 详细文档：[backend/paddleocr_vl/README.md](backend/paddleocr_vl/README.md)

---

## 🌟 项目简介

MinerU Tianshu（天枢）是一个**企业级 AI 数据预处理平台**，将非结构化数据转换为 AI 可用的结构化格式：

- **📄 文档**: PDF、Word、Excel、PPT → Markdown/JSON（MinerU、PaddleOCR-VL 109+ 语言、水印去除🧪）
- **🎬 视频**: MP4、AVI、MKV → 语音转写 + 关键帧 OCR🧪（FFmpeg + SenseVoice）
- **🎙️ 音频**: MP3、WAV、M4A → 文字转写 + 说话人识别（SenseVoice 多语言）
- **🖼️ 图片**: JPG、PNG → 文字提取 + 结构化（多 OCR 引擎 + 水印去除🧪）
- **🧬 生物格式**: FASTA、GenBank → Markdown/JSON（插件化引擎，易扩展）
- **🏗️ 企业特性**: GPU 负载均衡、任务队列、JWT 认证、MCP 协议、现代化 Web 界面

## 📸 功能展示

<div align="center">

### 📊 仪表盘 - 实时监控

<img src="./docs/img/dashboard.png" alt="仪表盘" width="80%"/>

*实时监控队列统计和最近任务*

---

### 📤 任务提交 - 文件拖拽上传

<img src="./docs/img/submit.png" alt="任务提交" width="80%"/>

*支持批量处理和高级配置*

---

### ⚙️ 队列管理 - 系统监控

<img src="./docs/img/tasks.png" alt="队列管理" width="80%"/>

*重置超时任务、清理旧文件*

</div>

### 主要功能

- ✅ **用户认证**: JWT 认证、角色权限、API Key 管理
- ✅ **任务管理**: 拖拽上传、批量处理、实时追踪、Markdown/JSON 预览
- ✅ **队列管理**: 系统监控、超时重置、文件清理
- ✅ **MCP 协议**: AI 助手（Claude Desktop）无缝集成
- ✅ **Docker 部署**: 一键部署、GPU 支持、完整容器化

### 支持的文件格式

- 📄 **文档**: PDF、Word、Excel、PPT（MinerU、PaddleOCR-VL、MarkItDown）
- 🖼️ **图片**: JPG、PNG、BMP、TIFF（MinerU、PaddleOCR-VL）
- 🎙️ **音频**: MP3、WAV、M4A、FLAC（SenseVoice 多语言、说话人识别、情感识别）
- 🎬 **视频**: MP4、AVI、MKV、MOV、WebM（音频转写 + 关键帧 OCR🧪）
- 🧬 **生物格式**: FASTA、GenBank（序列统计、碱基分析、GC 含量）
- 🌐 **其他**: HTML、Markdown、TXT、CSV

## 🏗️ 项目结构

```
mineru-server/
├── frontend/              # Vue 3 前端（TypeScript + TailwindCSS）
│   ├── src/               # 源码（api、components、views、stores、router）
│   └── vite.config.ts
│
├── backend/               # Python 后端（FastAPI + LitServe）
│   ├── api_server.py      # API 服务器
│   ├── litserve_worker.py # GPU Worker Pool
│   ├── mcp_server.py      # MCP 协议服务器
│   ├── auth/              # 认证授权（JWT、SSO）
│   ├── audio_engines/     # 音频引擎（SenseVoice）
│   ├── video_engines/     # 视频引擎（FFmpeg + OCR）
│   ├── format_engines/    # 格式引擎（FASTA、GenBank）
│   ├── remove_watermark/  # 水印去除（YOLO11x + LaMa）
│   └── requirements.txt
│
├── scripts/               # 部署脚本
│   ├── docker-setup.sh    # Linux/Mac 部署
│   └── docker-setup.bat   # Windows 部署
│
├── docker-compose.yml     # Docker 编排配置
└── Makefile               # 快捷命令
```

---

## 🏗️ 统一镜像架构

Tianshu 采用**一个镜像，自动适配所有环境**的设计理念，无需用户选择 CPU 或 GPU 版本：

### 核心特性

```
单一镜像：tianshu-backend:latest
  │
  ├─ 基于 NVIDIA CUDA 12.6.2
  ├─ 包含 GPU 版本的 PyTorch 和 PaddlePaddle
  │
  └─ 启动时自动检测：
      ├─ 有 GPU → 使用 GPU 模式（5-10x 速度）
      └─ 无 GPU → 自动降级 CPU 模式
```

### 设计优势

- 🎯 **智能适配**：自动检测 GPU，有则加速，无则 CPU 降级
- ⚡ **GPU 加速**：如有 NVIDIA GPU，处理速度提升 5-10 倍
- 🖥️ **CPU 兼容**：无 GPU 服务器也可正常运行
- 📦 **统一镜像**：无需选择版本，一个镜像走天下
- 🔄 **无缝切换**：同一镜像可在不同服务器间迁移
- 🛠️ **简化维护**：只需维护一套代码和配置

### 技术实现

- **自动适配**: LitServe `accelerator="auto"` 智能检测设备
- **GPU 隔离**: `CUDA_VISIBLE_DEVICES` 进程级 GPU 隔离
- **智能降级**: PyTorch/PaddlePaddle 自动使用 CPU
- **环境变量**: `DEVICE_MODE=auto|gpu|cpu` 灵活控制

### 性能对比

| 任务类型 | GPU 模式 | CPU 模式 | 加速比 |
|---------|---------|---------|--------|
| 10 页 PDF | 5-10 秒 | 30-60 秒 | 6x |
| 100 页 PDF | 30-60 秒 | 5-10 分钟 | 8x |
| 1 小时音频 | 1-2 分钟 | 10-15 分钟 | 7x |

---

## 🚀 快速开始

### 方式一：Docker 部署（⭐ 推荐）

**前置要求**：Docker 20.10+、Docker Compose 2.0+、NVIDIA Container Toolkit（GPU 可选）

```bash
# 一键部署
make setup

# 或使用脚本
./scripts/docker-setup.sh    # Linux/Mac
scripts\docker-setup.bat     # Windows

# 常用命令
make start    # 启动服务
make stop     # 停止服务
make logs     # 查看日志
```

**服务访问**：
- 前端：http://localhost:80
- API 文档：http://localhost:8000/docs
- Worker：http://localhost:8001
- MCP：http://localhost:8002

---

### 方式二：本地开发部署

**前置要求**：Node.js 18+、Python 3.8+、CUDA（可选）

**1. 安装依赖**

```bash
cd backend
bash install.sh              # Linux/macOS 自动安装
# 或 pip install -r requirements.txt
```

**2. 启动后端**

```bash
cd backend
python start_all.py          # 启动所有服务
python start_all.py --enable-mcp  # 启用 MCP 协议
```

**3. 启动前端**

```bash
cd frontend
npm install
npm run dev                  # http://localhost:3000
```

## 📖 使用指南

### 提交任务

1. 点击"提交任务"，拖拽上传文件（支持批量）
2. 配置选项：选择引擎（pipeline/vlm）、语言、公式/表格识别、优先级
3. 提交后在仪表盘或任务列表查看状态
4. 完成后预览/下载 Markdown 或 JSON 结果

### 引擎选择

- **pipeline**: MinerU 标准流程，通用文档解析
- **vlm-transformers/vlm-vllm-engine**: MinerU VLM 模式
<!-- - **deepseek-ocr**: DeepSeek OCR，高精度需求 -->
- **paddleocr-vl**: 109+ 语言，自动方向矫正

## 🎯 核心特性

- **Worker 主动拉取**: 0.5秒响应，无需调度器触发
- **GPU 负载均衡**: LitServe 自动调度，避免显存冲突，多 GPU 隔离
- **并发安全**: 原子操作防止任务重复，支持多 Worker 并发
- **多解析引擎**: MinerU、PaddleOCR-VL、MarkItDown、格式引擎
- **自动清理**: 定期清理旧文件，保留数据库记录
- **现代化 UI**: TailwindCSS 美观界面，响应式设计，实时更新

## ⚙️ 配置说明

### 后端配置

```bash
# 自定义启动
python backend/start_all.py \
  --api-port 8000 \
  --worker-port 9000 \
  --accelerator cuda \
  --devices 0,1 \
  --workers-per-device 2 \
  --enable-mcp --mcp-port 8002
```

详见 [backend/README.md](backend/README.md)

### MCP 协议集成

MinerU Tianshu 支持 **Model Context Protocol (MCP)**，让 AI 助手（Claude Desktop）直接调用文档解析服务。

**1. 启动服务**

```bash
cd backend
python start_all.py --enable-mcp  # MCP Server 端口 8002（默认）
```

**2. 配置 Claude Desktop**

编辑配置文件（`%APPDATA%\Claude\claude_desktop_config.json` Windows / `~/Library/Application Support/Claude/claude_desktop_config.json` macOS）：

```json
{
  "mcpServers": {
    "mineru-tianshu": {
      "url": "http://localhost:8002/sse",
      "transport": "sse"
    }
  }
}
```

> **注意**：MCP Server 默认端口为 8002（本地和 Docker 部署均相同）

**3. 使用**

在 Claude 中直接说：`帮我解析这个 PDF：C:/Users/user/doc.pdf`

**支持的工具**：
- `parse_document`: 解析文档（Base64 或 URL，最大 500MB）
- `get_task_status`: 查询任务状态
- `list_tasks`: 列出最近任务
- `get_queue_stats`: 获取队列统计

详见 [backend/MCP_GUIDE.md](backend/MCP_GUIDE.md)

## 🚢 生产部署

### 离线部署（推荐）

Tianshu 支持**完全离线部署**，提供两种部署模式：

#### 方式 1：统一版（GPU 自动降级 CPU）- 推荐生产环境

适用于 Linux 服务器（有 GPU 则加速，无 GPU 自动降级 CPU）：

```bash
# 1. 在联网环境构建镜像（Linux/Mac 均可）
./scripts/build-offline.sh

# 2. 传输到生产服务器
rsync -avz docker-images/ user@prod-server:/opt/tianshu/

# 3. 在生产服务器部署（自动检测 GPU/CPU）
cd /opt/tianshu
./deploy-offline.sh
```

**脚本说明**：

##### 🔨 `build-offline.sh` - 镜像构建脚本

在**联网环境**中一次性构建，输出所有部署文件。用于在开发环境构建 Docker 镜像和下载模型，然后传输到生产服务器离线部署。

**功能**：
- ✅ 自动检测 NVIDIA 环境（可选，仅提示）
- ✅ 下载所有模型文件到 `./models-offline/`（~15GB）
- ✅ 构建后端统一镜像（GPU with CPU fallback）
- ✅ 构建前端镜像
- ✅ 拉取 RustFS 对象存储镜像
- ✅ 导出所有镜像为 tar.gz（包含 Docker 配置和启动脚本）
- ✅ 生成 manifest.json 记录模型信息

**使用**：
```bash
# 基础用法：构建 amd64 镜像
./scripts/build-offline.sh

# 环境变量控制
PLATFORM=arm64 ./scripts/build-offline.sh  # 指定平台（默认 amd64）

# 输出文件（在 docker-images/ 目录）
# ├── tianshu-backend-amd64.tar.gz      # 后端统一镜像
# ├── tianshu-frontend-amd64.tar.gz     # 前端镜像
# ├── rustfs-amd64.tar.gz               # 对象存储镜像
# ├── models-offline.tar.gz             # 所有模型（~15GB）
# ├── docker-compose.yml                # Docker Compose 配置
# ├── .env.example                      # 环境变量示例
# ├── deploy-offline.sh                 # 部署脚本
# └── deploy-offline-cpu.sh             # CPU 模式部署脚本
```

**时间预估**：
- 首次运行：60-90 分钟（包括模型下载和镜像构建）
- 后续运行：10-20 分钟（使用缓存）

**故障排查**：
- 模型下载失败：手动运行 `python3 backend/download_models.py --output models-offline`
- 镜像构建失败：检查磁盘空间（至少需要 100GB）和 Docker 环境

---

##### 📥 `deploy-offline.sh` - 统一部署脚本（推荐）

在**生产服务器**中部署的一键脚本。自动检测 GPU/CPU 环境并启动所有服务。

**功能**：
- ✅ 检测 NVIDIA 驱动和 CUDA 环境
- ✅ 验证 NVIDIA Container Toolkit 状态
- ✅ 加载所有 Docker 镜像（5-10 分钟）
- ✅ 解压模型文件到 `./models-offline/`（5-10 分钟）
- ✅ 创建必要的目录结构（data/, logs/）
- ✅ 自动生成 .env 配置文件
- ✅ 生成安全的 JWT 密钥
- ✅ 自动检测服务器 IP 并配置 `RUSTFS_PUBLIC_URL`
- ✅ 启动所有 Docker Compose 服务
- ✅ 健康检查验证服务状态
- ✅ 验证 GPU 访问权限（如有 GPU）

**使用**：
```bash
# 确保在部署文件目录
cd /opt/tianshu

# 一键部署（自动检测 GPU/CPU）
./deploy-offline.sh

# 后续查看状态
docker compose ps              # 查看容器状态
docker compose logs -f         # 实时日志
docker compose logs -f backend # 查看特定服务日志

# 停止服务
docker compose down
```

**部署流程**：
1. 检测 NVIDIA 环境（自动检测 GPU，无 GPU 自动降级 CPU）
2. 验证所需文件（镜像、模型等）
3. 加载 Docker 镜像
4. 解压模型文件
5. 创建目录结构
6. 配置环境变量和 JWT 密钥
7. 启动容器服务
8. 等待服务初始化（1-2 分钟）
9. 验证 GPU 访问（如适用）
10. 显示访问 URL 和后续命令

**服务访问**：
```
Web UI:     http://<server-ip>:80
API:        http://<server-ip>:8000
API Docs:   http://<server-ip>:8000/docs
RustFS:     http://<server-ip>:9001
```

**首次启动**：
- 第一次启动时会初始化模型（自动从 models-offline 复制）
- Worker 服务启动较慢（1-2 分钟），请耐心等待
- 建议上传小文件（5-10 页 PDF）测试

**故障排查**：
```bash
# 查看容器日志
docker compose logs backend
docker compose logs worker

# 查看 GPU 使用情况
docker compose exec worker nvidia-smi

# 重启服务
docker compose restart worker
```

---

##### 📦 `backend/download_models.py` - 模型下载脚本

独立的模型下载工具，支持灵活的模型选择和重新下载。

**功能**：
- ✅ 从 HuggingFace、ModelScope 下载模型
- ✅ 验证模型完整性
- ✅ 支持选择性下载（单个或多个模型）
- ✅ 断点续传（自动重试失败的下载）
- ✅ 生成 manifest.json 记录下载信息

**使用**：
```bash
# 下载所有模型
python3 backend/download_models.py --output ./models-offline

# 仅下载特定模型
python3 backend/download_models.py --output ./models-offline --models mineru,sensevoice

# 强制重新下载（跳过已存在的文件）
python3 backend/download_models.py --output ./models-offline --force

# 使用国内镜像加速
HF_ENDPOINT=https://hf-mirror.com python3 backend/download_models.py --output ./models-offline
```

**支持的模型**：
- `mineru` - MinerU PDF 解析模型（必需）
- `paddleocr` - PaddleOCR 多语言识别（自动下载）
- `sensevoice` - SenseVoice 语音识别（推荐）
- `paraformer` - Paraformer 说话人分离（可选）
- `yolo11` - YOLO11x 水印检测（可选）
- `lama` - LaMa 水印修复（可选）

**时间预估**：
- 所有模型：60-90 分钟（取决于网络速度）
- 推荐模型：30-45 分钟

---

##### ⚙️ `scripts/init-models.sh` - 模型初始化脚本

容器启动时自动运行，从外部卷复制模型到容器内。

**功能**：
- ✅ 检测设备模式（GPU/CPU）
- ✅ 检查是否已初始化（跳过重复复制）
- ✅ 从 `/models-external` 复制模型到容器内缓存
- ✅ 创建必要的目录结构
- ✅ 生成初始化标记（加快后续启动）

**工作原理**：
- 容器启动时自动调用
- 首次运行：复制模型（5-10 分钟）
- 后续运行：使用缓存标记，直接跳过（<1 秒）

---

#### 方式 2：CPU 专用版（Mac/无 GPU 环境）

适用于 Mac（Apple Silicon/Intel）和无 GPU 的 Linux 环境：

```bash
# 1. 在联网环境构建镜像
./scripts/build-offline.sh

# 2. 传输构建产物（可选：直接在目标机器构建可跳过此步）
rsync -avz docker-images/ user@target:/opt/tianshu/

# 3. 在目标机器部署（强制 CPU 模式）
cd /opt/tianshu
./deploy-offline-cpu.sh
```

**特点**：
- ✅ **强制 CPU 模式**：适合 Mac 和无 GPU 环境
- ✅ **Rosetta 2 支持**：Apple Silicon Mac 自动使用 x86_64 仿真
- ✅ **简化配置**：自动跳过 GPU 检测和配置
- ✅ **独立脚本**：不依赖 GPU 环境

**部署步骤**：
```bash
cd /opt/tianshu
./deploy-offline-cpu.sh
```

**性能注意**：
- CPU 模式比 GPU 模式慢 5-10 倍
- 建议分配足够的 CPU 核心（8+ 核）
- 建议分配充足的内存（16GB+）

---

#### 其他工具脚本

##### 📤 `scripts/upload-to-server.sh` - 文件传输脚本

自动化将构建产物传输到生产服务器并触发部署。

**使用**：
```bash
# 基础用法
./scripts/upload-to-server.sh [server_user] [server_host] [server_path]

# 示例
./scripts/upload-to-server.sh root 192.168.1.100 /opt/tianshu

# 功能
# - 清理本地多余文件（models-offline/、data/ 等）
# - 创建临时文件夹并复制必要文件
# - 使用 rsync 快速传输
# - 自动清理临时文件
# - 可选自动触发远程部署脚本
```

**特点**：
- ✅ 仅传输必要文件（节省带宽）
- ✅ 支持断点续传（网络中断自动重试）
- ✅ 可选的自动部署触发

---

**流程总结**：

```
开发环境（联网）：
  build-offline.sh
    ├─ 下载模型（backend/download_models.py）
    ├─ 构建镜像
    ├─ 导出镜像和文件
    └─ 输出到 docker-images/

传输文件：
  rsync / upload-to-server.sh
    └─ 传输到生产服务器

生产环境（离线）：
  deploy-offline.sh / deploy-offline-cpu.sh
    ├─ 加载镜像
    ├─ 解压模型
    ├─ 配置环境
    └─ 启动服务（自动检测 GPU/CPU）
```

**特点**：
- ✅ **统一镜像**：自动检测 GPU，有则加速，无则 CPU 降级
- ✅ **跨平台构建**：支持在 Mac（Apple Silicon/Intel）构建 Linux amd64 镜像
- ✅ **完全离线**：所有模型（~15GB）和依赖预先打包
- ✅ **一键部署**：自动配置环境变量、JWT 密钥、RustFS 对象存储
- ✅ **Office 文档支持**：自动转换 .doc/.docx/.pptx 等格式为 PDF 后处理

**关键修复**：
- 🔧 Worker uploads 目录读写权限（支持 Office 转 PDF）
- 🔧 albumentations/albucore 版本锁定（解决 MinerU 公式识别依赖）
- 🔧 RustFS 镜像平台指定（确保 amd64 架构一致性）

📖 **详细说明**：[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

### 在线 Docker 部署

推荐使用 Docker Compose 一键部署：

```bash
# 一键部署
docker compose up -d

# 或使用 Make 命令
make setup
```

### 手动部署

如需手动部署：

**前端构建**：`cd frontend && npm run build`（产物在 `dist/`）

**Nginx 配置**：
```nginx
server {
    listen 80;
    root /path/to/frontend/dist;
    location / { try_files $uri $uri/ /index.html; }
    location /api/ { proxy_pass http://localhost:8000/api/; }
}
```

**后端部署**：`cd backend && python start_all.py --api-port 8000 --worker-port 9000`

## 📚 技术栈

**前端**：Vue 3、TypeScript、Vite、TailwindCSS、Pinia、Vue Router

**后端**：FastAPI、LitServe、MinerU、PaddleOCR、SenseVoice、SQLite、Loguru

## 🔧 故障排查

**前端无法连接**：`curl http://localhost:8000/api/v1/health` 检查后端，查看 `vite.config.ts` 代理配置

**Worker 无法启动**：`nvidia-smi` 检查 GPU，`pip list | grep mineru` 检查依赖

详见 [frontend/README.md](frontend/README.md) 和 [backend/README.md](backend/README.md)

## 📄 API 文档

访问 <http://localhost:8000/docs> 查看完整 API 文档

主要端点：
- `POST /api/v1/tasks/submit` - 提交任务
- `GET /api/v1/tasks/{task_id}` - 查询状态
- `GET /api/v1/queue/stats` - 队列统计

## 🤝 贡献

欢迎提交 Issue 和 Pull Request!

## 🙏 鸣谢

本项目基于以下优秀的开源项目构建：

**核心引擎**

- [MinerU](https://github.com/opendatalab/MinerU) - PDF/图片文档解析
- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) - 多语言 OCR 引擎
- [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) - 语音识别与说话人识别
- [FunASR](https://github.com/modelscope/FunASR) - 语音识别框架
- [MarkItDown](https://github.com/microsoft/markitdown) - 文档转换工具

**框架与工具**

- [LitServe](https://github.com/Lightning-AI/LitServe) - GPU 负载均衡
- [FastAPI](https://fastapi.tiangolo.com/) - 后端 Web 框架
- [Vue.js](https://vuejs.org/) - 前端框架
- [TailwindCSS](https://tailwindcss.com/) - CSS 框架
- [PyTorch](https://pytorch.org/) - 深度学习框架

感谢所有开源贡献者！

## 📜 许可证

本项目采用 [Apache License 2.0](LICENSE) 开源协议。

```
Copyright 2024 MinerU Tianshu Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

<div align="center">

**天枢 (Tianshu)** - 企业级多 GPU 文档解析服务 ⚡️

*北斗第一星，寓意核心调度能力*

<br/>

### 喜欢这个项目？

<a href="https://github.com/magicyuan876/mineru-tianshu/stargazers">
  <img src="https://img.shields.io/github/stars/magicyuan876/mineru-tianshu?style=social" alt="Stars"/>
</a>
<a href="https://github.com/magicyuan876/mineru-tianshu/network/members">
  <img src="https://img.shields.io/github/forks/magicyuan876/mineru-tianshu?style=social" alt="Forks"/>
</a>

**点击 ⭐ Star 支持项目发展，感谢！**

</div>
