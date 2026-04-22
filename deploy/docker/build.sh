#!/bin/bash
# Tianshu 镜像构建脚本
#
# 使用方式:
#   bash deploy/docker/build.sh                # 构建所有镜像（backend + frontend）
#   bash deploy/docker/build.sh --backend-only  # 仅构建后端镜像
#   bash deploy/docker/build.sh --frontend-only # 仅构建前端镜像
#   bash deploy/docker/build.sh --models-only   # 仅构建模型镜像

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")"

# ============================================================================
# 配置
# ============================================================================
PLATFORM="${PLATFORM:-amd64}"
MODELS_DIR="${ROOT_DIR}/models-offline"

# 解析命令行参数
MODE="all"
for arg in "$@"; do
    case "$arg" in
        --backend-only)  MODE="backend-only" ;;
        --frontend-only) MODE="frontend-only" ;;
        --models-only)   MODE="models-only" ;;
        --platform=*)    PLATFORM="${arg#*=}" ;;
        -h|--help)       MODE="help" ;;
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
    echo "Usage: bash deploy/docker/build.sh [MODE] [OPTIONS]"
    echo ""
    echo "Modes:"
    echo "  （默认）          构建所有镜像（backend + frontend）"
    echo ""
    echo "  --backend-only    仅构建后端镜像"
    echo "                    输出: 本地镜像 tianshu-backend:latest (~16GB)"
    echo ""
    echo "  --frontend-only   仅构建前端镜像"
    echo "                    输出: 本地镜像 tianshu-frontend:latest (~55MB)"
    echo ""
    echo "  --models-only     仅构建模型镜像"
    echo "                    输出: 本地镜像 tianshu-models:latest (~30GB)"
    echo ""
    echo "Options:"
    echo "  --platform=amd64  目标平台（默认 amd64）"
    echo "  -h, --help        显示此帮助"
    echo ""
    echo "典型工作流:"
    echo "  # 首次部署：构建所有镜像 + 模型镜像"
    echo "  bash deploy/docker/build.sh"
    echo "  bash deploy/docker/build.sh --models-only"
    echo "  bash deploy/docker/push-to-registry.sh backend"
    echo "  bash deploy/docker/push-to-registry.sh frontend"
    echo "  bash deploy/docker/push-to-registry.sh models"
    echo ""
    echo "  # 日常代码更新"
    echo "  bash deploy/docker/build.sh --backend-only"
    echo "  bash deploy/docker/push-to-registry.sh backend"
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
    log_info "Checking models..."
    if [ ! -d "$MODELS_DIR" ] || [ -z "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
        log_warning "Models directory not found or empty!"
        log_info "Running model download script..."

        if ! command -v python3 &> /dev/null; then
            log_error "Python 3 is not installed!"
            exit 1
        fi

        python3 -m pip install --quiet huggingface-hub modelscope loguru 2>/dev/null || true
        python3 "${ROOT_DIR}/backend/download_models.py" --output "$MODELS_DIR"

        if [ $? -ne 0 ]; then
            log_error "Model download failed!"
            log_info "Please run manually: python3 ${ROOT_DIR}/backend/download_models.py --output $MODELS_DIR"
            exit 1
        fi
        log_success "Models downloaded successfully"
    else
        log_success "Models found: $MODELS_DIR"
    fi
}

# ============================================================================
# 构建所有镜像（backend + frontend）
# ============================================================================
build_all() {
    log_info "=========================================="
    log_info "Build All Images"
    log_info "=========================================="
    log_info "Platform: linux/$PLATFORM"
    echo ""

    check_docker
    echo ""

    # 构建后端镜像
    log_info "Building backend image..."
    log_info "   This may take 60-90 minutes on first build (cached afterwards)..."
    echo ""

    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file "${ROOT_DIR}/backend/Dockerfile.offline" \
        --tag tianshu-backend:latest \
        --load \
        "${ROOT_DIR}"

    log_success "Backend image built: tianshu-backend:latest"
    echo ""

    # 构建前端镜像
    log_info "Building frontend image..."
    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file "${ROOT_DIR}/frontend/Dockerfile" \
        --tag tianshu-frontend:latest \
        --load \
        "${ROOT_DIR}"
    log_success "Frontend image built: tianshu-frontend:latest"
    echo ""

    log_info "=========================================="
    log_success "All Images Built!"
    log_info "=========================================="
    echo ""
    log_info "Local images:"
    docker images --format "  {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "tianshu-backend|tianshu-frontend" | head -5
    echo ""
    log_info "Next steps - push to registry:"
    echo ""
    echo "  bash deploy/docker/push-to-registry.sh backend"
    echo "  bash deploy/docker/push-to-registry.sh frontend"
    echo ""
}

# ============================================================================
# 仅构建后端镜像
# ============================================================================
build_backend_only() {
    log_info "=========================================="
    log_info "Backend-Only Build"
    log_info "=========================================="
    log_info "Platform: linux/$PLATFORM"
    echo ""

    check_docker
    echo ""

    log_info "Building backend image..."
    log_info "   Docker layer cache will speed up rebuilds when only code changes..."
    echo ""

    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file "${ROOT_DIR}/backend/Dockerfile.offline" \
        --tag tianshu-backend:latest \
        --load \
        "${ROOT_DIR}"

    log_success "Backend image built: tianshu-backend:latest"
    echo ""

    log_info "=========================================="
    log_success "Backend-Only Build Complete!"
    log_info "=========================================="
    echo ""
    log_info "Next step - push to registry:"
    echo ""
    echo "  bash deploy/docker/push-to-registry.sh backend"
    echo ""
}

# ============================================================================
# 仅构建前端镜像
# ============================================================================
build_frontend_only() {
    log_info "=========================================="
    log_info "Frontend-Only Build"
    log_info "=========================================="
    log_info "Platform: linux/$PLATFORM"
    echo ""

    check_docker
    echo ""

    log_info "Building frontend image..."
    echo ""

    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file "${ROOT_DIR}/frontend/Dockerfile" \
        --tag tianshu-frontend:latest \
        --load \
        "${ROOT_DIR}"

    log_success "Frontend image built: tianshu-frontend:latest"
    echo ""

    log_info "=========================================="
    log_success "Frontend-Only Build Complete!"
    log_info "=========================================="
    echo ""
    log_info "Next step - push to registry:"
    echo ""
    echo "  bash deploy/docker/push-to-registry.sh frontend"
    echo ""
}

# ============================================================================
# 仅构建模型镜像
# ============================================================================
build_models_only() {
    log_info "=========================================="
    log_info "Models-Only Build"
    log_info "=========================================="
    echo ""

    check_docker
    echo ""

    check_models
    echo ""

    log_info "Building models Docker image..."
    log_info "   This may take a while (~30GB)..."
    echo ""

    DOCKER_BUILDKIT=1 docker buildx build \
        --platform linux/$PLATFORM \
        --file "${ROOT_DIR}/deploy/docker/Dockerfile.models" \
        --tag tianshu-models:latest \
        --load \
        "${ROOT_DIR}"

    log_success "Models image built: tianshu-models:latest"
    echo ""

    docker images tianshu-models:latest
    echo ""

    log_info "=========================================="
    log_success "Models Image Build Complete!"
    log_info "=========================================="
    echo ""
    log_info "Next step - push to registry:"
    echo ""
    echo "  bash deploy/docker/push-to-registry.sh models"
    echo ""
}

# ============================================================================
# 主入口
# ============================================================================
# 捕获中断信号
trap 'log_warning "Build interrupted by user"; exit 130' SIGINT SIGTERM

case "$MODE" in
    all)
        build_all
        ;;
    backend-only)
        build_backend_only
        ;;
    frontend-only)
        build_frontend_only
        ;;
    models-only)
        build_models_only
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
