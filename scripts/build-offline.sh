#!/bin/bash
# Tianshu 离线镜像构建脚本
#
# 使用方式:
#   bash scripts/build-offline.sh              # 全量构建（首次部署）
#   bash scripts/build-offline.sh --deps-only  # 仅构建依赖层（切换到增量更新流程时用一次）
#   bash scripts/build-offline.sh --code-only  # 仅打包代码（日常代码更新）

set -e

# ============================================================================
# 配置
# ============================================================================
PLATFORM="${PLATFORM:-amd64}"
OUTPUT_DIR="./docker-images"
MODELS_DIR="./models-offline"

# 解析命令行参数
MODE="full"
for arg in "$@"; do
    case "$arg" in
        --deps-only)   MODE="deps-only" ;;
        --code-only)   MODE="code-only" ;;
        --full)        MODE="full" ;;
        --platform=*)  PLATFORM="${arg#*=}" ;;
        -h|--help)     MODE="help" ;;
    esac
done

# ============================================================================
# 颜色输出
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ============================================================================
# 使用说明
# ============================================================================
show_usage() {
    echo ""
    echo "Usage: bash scripts/build-offline.sh [MODE] [OPTIONS]"
    echo ""
    echo "Modes:"
    echo "  （默认）          全量构建：依赖 + 代码，用于首次部署"
    echo "                    输出: docker-images/tianshu-backend-amd64.tar.gz (~10GB)"
    echo ""
    echo "  --deps-only       仅构建依赖层，用于切换到增量更新流程（只需做一次）"
    echo "                    输出: docker-images/tianshu-backend-deps-amd64.tar.gz (~10GB)"
    echo ""
    echo "  --code-only       仅打包代码，用于日常代码更新（几 MB，几十秒）"
    echo "                    输出: docker-images/tianshu-backend-code-update.tar.gz (<10MB)"
    echo "                    前提：服务器已加载 tianshu-backend-deps:latest"
    echo ""
    echo "  --full            同默认，显式指定全量构建"
    echo ""
    echo "Options:"
    echo "  --platform=amd64  目标平台（默认 amd64）"
    echo "  -h, --help        显示此帮助"
    echo ""
    echo "典型工作流:"
    echo "  # 首次部署（或依赖变更时）"
    echo "  bash scripts/build-offline.sh"
    echo "  bash scripts/upload-all-to-server.sh root 192.168.1.100 /opt/tianshu"
    echo ""
    echo "  # 切换到增量更新（一次性操作）"
    echo "  bash scripts/build-offline.sh --deps-only"
    echo "  bash scripts/upload-spec-to-server.sh root 192.168.1.100 /opt/tianshu backend-deps"
    echo ""
    echo "  # 日常代码更新（此后每次代码变更）"
    echo "  bash scripts/build-offline.sh --code-only"
    echo "  bash scripts/upload-spec-to-server.sh root 192.168.1.100 /opt/tianshu backend-code"
    echo ""
}

# ============================================================================
# 检查 Docker 环境
# ============================================================================
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        if ! docker compose version &> /dev/null; then
            log_error "Docker Compose is not installed!"
            exit 1
        fi
    fi

    log_success "Docker: $(docker --version)"
}

# ============================================================================
# 检查并下载模型
# ============================================================================
check_models() {
    log_info "📦 Checking models..."
    if [ ! -d "$MODELS_DIR" ] || [ -z "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
        log_warning "Models directory not found or empty!"
        log_info "Running model download script..."

        if ! command -v python3 &> /dev/null; then
            log_error "Python 3 is not installed!"
            exit 1
        fi

        python3 -m pip install --quiet huggingface-hub modelscope loguru 2>/dev/null || true
        python3 backend/download_models.py --output "$MODELS_DIR"

        if [ $? -ne 0 ]; then
            log_error "Model download failed!"
            log_info "Please run manually: python3 backend/download_models.py --output $MODELS_DIR"
            exit 1
        fi
        log_success "Models downloaded successfully"
    else
        log_success "Models found: $MODELS_DIR"
    fi
}

# ============================================================================
# 全量构建（首次部署 / 依赖变更时使用）
# ============================================================================
build_full() {
    log_info "=========================================="
    log_info "🚀 Full Build: deps + code"
    log_info "=========================================="
    log_info "Platform: linux/$PLATFORM"
    log_info "Output:   $OUTPUT_DIR"
    echo ""

    check_docker
    echo ""

    # 检查 NVIDIA 环境
    log_info "🔍 Checking NVIDIA environment..."
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null 2>&1; then
        log_success "NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"
    else
        log_warning "NVIDIA GPU not detected (images will support GPU when deployed)"
    fi
    echo ""

    check_models
    echo ""

    # 构建后端镜像（完整版）
    log_info "📦 Building backend image (full)..."
    log_info "   This may take 60-90 minutes..."
    echo ""

    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file backend/Dockerfile.offline \
        --tag tianshu-backend:latest \
        --load \
        .

    log_success "Backend image built"
    echo ""

    # 同时 tag 一份 deps（方便后续切换到增量流程）
    log_info "🏷️  Also tagging as tianshu-backend-deps:latest for future incremental updates..."
    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file backend/Dockerfile.offline \
        --target dependencies \
        --tag tianshu-backend-deps:latest \
        --load \
        .
    log_success "Deps image tagged"
    echo ""

    # 构建前端镜像
    log_info "📦 Building frontend image..."
    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file frontend/Dockerfile \
        --tag tianshu-frontend:latest \
        --load \
        .
    log_success "Frontend image built"
    echo ""

    # 拉取 RustFS 镜像
    log_info "📥 Pulling RustFS image (platform: linux/$PLATFORM)..."
    docker pull --platform "linux/$PLATFORM" rustfs/rustfs:latest
    log_success "RustFS image pulled"
    echo ""

    # 导出镜像
    log_info "💾 Exporting images..."
    mkdir -p "$OUTPUT_DIR"

    log_info "   Exporting backend image (~10GB, 10-20 minutes)..."
    docker save tianshu-backend:latest | gzip > "$OUTPUT_DIR/tianshu-backend-$PLATFORM.tar.gz" &
    PID_BACKEND=$!

    log_info "   Exporting backend-deps image (~10GB, for future incremental use)..."
    docker save tianshu-backend-deps:latest | gzip > "$OUTPUT_DIR/tianshu-backend-deps-$PLATFORM.tar.gz" &
    PID_DEPS=$!

    log_info "   Exporting frontend image..."
    docker save tianshu-frontend:latest | gzip > "$OUTPUT_DIR/tianshu-frontend-$PLATFORM.tar.gz" &
    PID_FRONTEND=$!

    log_info "   Exporting rustfs image..."
    docker save rustfs/rustfs:latest | gzip > "$OUTPUT_DIR/rustfs-$PLATFORM.tar.gz" &
    PID_RUSTFS=$!

    wait $PID_BACKEND $PID_DEPS $PID_FRONTEND $PID_RUSTFS
    log_success "All images exported"
    echo ""

    # 处理模型文件
    log_info "📦 Packaging models..."
    if [ -d "$MODELS_DIR" ] && [ ! -f "$OUTPUT_DIR/models-offline.tar.gz" ]; then
        tar czf "$OUTPUT_DIR/models-offline.tar.gz" "$MODELS_DIR/"
        log_success "Models packaged"
    else
        log_warning "Models already packaged or directory not found, skipping"
    fi
    echo ""

    # 复制配置文件
    log_info "📋 Copying configuration files..."
    cp docker-compose.offline.yml "$OUTPUT_DIR/docker-compose.yml"
    cp docker-compose.offline.yml "$OUTPUT_DIR/docker-compose.offline.yml"
    [ -f ".env.example" ]                  && cp .env.example "$OUTPUT_DIR/"
    [ -f "scripts/deploy-offline.sh" ]     && cp scripts/deploy-offline.sh "$OUTPUT_DIR/" && chmod +x "$OUTPUT_DIR/deploy-offline.sh"
    [ -f "mcp_config.example.json" ]       && cp mcp_config.example.json "$OUTPUT_DIR/"
    log_success "Configuration files copied"
    echo ""

    print_full_summary
}

# ============================================================================
# 仅构建依赖层（切换到增量更新流程时用一次）
# ============================================================================
build_deps_only() {
    log_info "=========================================="
    log_info "🔧 Deps-Only Build"
    log_info "=========================================="
    log_info "Platform: linux/$PLATFORM"
    log_info "Output:   $OUTPUT_DIR/tianshu-backend-deps-$PLATFORM.tar.gz"
    echo ""

    check_docker
    echo ""

    log_info "📦 Building dependencies stage (no code)..."
    log_info "   This may take 60-90 minutes on first build (cached afterwards)..."
    echo ""

    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file backend/Dockerfile.offline \
        --target dependencies \
        --tag tianshu-backend-deps:latest \
        --load \
        .

    log_success "Deps image built: tianshu-backend-deps:latest"
    echo ""

    log_info "💾 Exporting deps image..."
    mkdir -p "$OUTPUT_DIR"
    docker save tianshu-backend-deps:latest | gzip > "$OUTPUT_DIR/tianshu-backend-deps-$PLATFORM.tar.gz"
    log_success "Exported"
    echo ""

    ls -lh "$OUTPUT_DIR/tianshu-backend-deps-$PLATFORM.tar.gz"
    echo ""

    log_info "=========================================="
    log_success "✅ Deps-Only Build Complete!"
    log_info "=========================================="
    echo ""
    log_info "📋 下一步：上传 deps 镜像到服务器（只需做一次）"
    echo ""
    echo "  bash scripts/upload-spec-to-server.sh root 192.168.1.100 /opt/tianshu backend-deps"
    echo ""
    log_info "📋 之后每次代码更新只需运行:"
    echo ""
    echo "  bash scripts/build-offline.sh --code-only"
    echo "  bash scripts/upload-spec-to-server.sh root 192.168.1.100 /opt/tianshu backend-code"
    echo ""
}

# ============================================================================
# 仅打包代码（日常代码更新）
# ============================================================================
build_code_only() {
    log_info "=========================================="
    log_info "⚡ Code-Only Package (Incremental Update)"
    log_info "=========================================="
    echo ""

    # 检查 Dockerfile.code
    if [ ! -f "Dockerfile.code" ]; then
        log_error "Dockerfile.code not found!"
        log_info "Please ensure the file exists in the project root directory."
        exit 1
    fi

    # 检查本地是否有 deps 镜像（用于验证 Dockerfile.code 能正常 build）
    if ! docker image inspect tianshu-backend-deps:latest &> /dev/null; then
        log_warning "tianshu-backend-deps:latest not found locally, skipping local build verification"
        log_info "Make sure the server has tianshu-backend-deps:latest loaded"
    else
        log_info "🔍 Verifying Dockerfile.code builds correctly..."
        if DOCKER_BUILDKIT=1 docker build \
            --file Dockerfile.code \
            --tag tianshu-backend:latest \
            . > /dev/null 2>&1; then
            log_success "Build verification passed"
        else
            log_warning "Local build verification failed (may be platform mismatch on macOS), skipping"
            log_info "The code package will still be created for server-side build"
        fi
    fi
    echo ""

    # 创建临时目录，组织 build context
    log_info "📦 Packaging code files..."
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    mkdir -p "$TEMP_DIR/backend"
    mkdir -p "$TEMP_DIR/scripts"

    # 复制 build context 所需文件
    cp -r backend "$TEMP_DIR/"
    cp pyproject.toml "$TEMP_DIR/" 2>/dev/null || true
    cp Dockerfile.code "$TEMP_DIR/Dockerfile.code"
    cp scripts/docker-entrypoint.sh "$TEMP_DIR/scripts/"
    cp scripts/init-models.sh "$TEMP_DIR/scripts/"

    # 打包
    mkdir -p "$OUTPUT_DIR"
    tar czf "$OUTPUT_DIR/tianshu-backend-code-update.tar.gz" -C "$TEMP_DIR" .

    log_success "Code update package created"
    echo ""
    ls -lh "$OUTPUT_DIR/tianshu-backend-code-update.tar.gz"
    echo ""

    log_info "=========================================="
    log_success "✅ Code-Only Package Complete!"
    log_info "=========================================="
    echo ""
    log_info "📋 上传并部署到服务器:"
    echo ""
    echo "  bash scripts/upload-spec-to-server.sh root 192.168.1.100 /opt/tianshu backend-code"
    echo ""
    log_info "📋 或手动操作:"
    echo ""
    echo "  scp $OUTPUT_DIR/tianshu-backend-code-update.tar.gz user@server:/tmp/"
    echo "  ssh user@server 'mkdir -p /tmp/tianshu-update && \\"
    echo "    tar xzf /tmp/tianshu-backend-code-update.tar.gz -C /tmp/tianshu-update/ && \\"
    echo "    cd /tmp/tianshu-update && \\"
    echo "    docker build -f Dockerfile.code -t tianshu-backend:latest . && \\"
    echo "    cd /opt/tianshu && \\"
    echo "    docker-compose restart backend worker scheduler && \\"
    echo "    rm -rf /tmp/tianshu-update /tmp/tianshu-backend-code-update.tar.gz'"
    echo ""
}

# ============================================================================
# 全量构建完成摘要
# ============================================================================
print_full_summary() {
    log_info "=========================================="
    log_success "✅ Full Build Complete!"
    log_info "=========================================="
    echo ""
    log_info "📦 Files in $OUTPUT_DIR:"
    ls -lh "$OUTPUT_DIR/"
    echo ""
    log_info "💾 Total size: $(du -sh "$OUTPUT_DIR" | cut -f1)"
    echo ""
    log_info "📋 首次部署到服务器:"
    echo ""
    echo "  bash scripts/upload-all-to-server.sh root 192.168.1.100 /opt/tianshu"
    echo ""
    log_info "📋 后续代码增量更新（更快）:"
    echo ""
    echo "  bash scripts/build-offline.sh --code-only"
    echo "  bash scripts/upload-spec-to-server.sh root 192.168.1.100 /opt/tianshu backend-code"
    echo ""
}

# ============================================================================
# 主入口
# ============================================================================
case "$MODE" in
    full)
        build_full
        ;;
    deps-only)
        build_deps_only
        ;;
    code-only)
        build_code_only
        ;;
    help)
        show_usage
        exit 0
        ;;
    *)
        log_error "Unknown mode: $MODE"
        show_usage
        exit 1
        ;;
esac

# 捕获中断信号
trap 'log_warning "Build interrupted by user"; exit 130' SIGINT SIGTERM
