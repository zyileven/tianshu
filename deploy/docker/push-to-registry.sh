#!/bin/bash
# Tianshu 推送镜像到阿里云镜像仓库
# 将本地已构建的镜像 tag 并推送到远程仓库（不执行构建）
#
# 使用方式:
#   bash deploy/docker/push-to-registry.sh backend      # 推送后端镜像
#   bash deploy/docker/push-to-registry.sh frontend      # 推送前端镜像
#   bash deploy/docker/push-to-registry.sh models        # 推送模型镜像
#   bash deploy/docker/push-to-registry.sh rustfs        # 推送 RustFS 镜像
#   bash deploy/docker/push-to-registry.sh backend --tag v1.0.0  # 指定版本标签

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")"

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
# 从 .env 加载配置
# ============================================================================
load_env() {
    local env_file=""
    if [ -f "${ROOT_DIR}/.env" ]; then
        env_file="${ROOT_DIR}/.env"
    elif [ -f "${ROOT_DIR}/.env.example" ]; then
        env_file="${ROOT_DIR}/.env.example"
    fi

    if [ -n "$env_file" ]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^["'"'"']//;s/["'"'"']$//')
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            case "$key" in
                REGISTRY_PREFIX)   REGISTRY_PREFIX="${REGISTRY_PREFIX:-$value}" ;;
                REGISTRY_USERNAME) REGISTRY_USERNAME="${REGISTRY_USERNAME:-$value}" ;;
                REGISTRY_PASSWORD) REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-$value}" ;;
            esac
        done < "$env_file"
    fi
}

# ============================================================================
# 使用说明
# ============================================================================
show_usage() {
    echo ""
    echo "Usage: bash deploy/docker/push-to-registry.sh <IMAGE_TYPE> [OPTIONS]"
    echo ""
    echo "IMAGE_TYPE (必选，每次只能推送一个):"
    echo "  backend     推送后端镜像  (本地: tianshu-backend:latest)"
    echo "  frontend    推送前端镜像  (本地: tianshu-frontend:latest)"
    echo "  models      推送模型镜像  (本地: tianshu-models:latest)"
    echo "  rustfs      推送 RustFS   (本地: rustfs/rustfs:latest)"
    echo ""
    echo "Options:"
    echo "  --tag <tag>   远程标签 (默认: latest)"
    echo "  -h, --help    显示此帮助"
    echo ""
    echo "仓库配置从 .env 读取 (REGISTRY_PREFIX, REGISTRY_USERNAME, REGISTRY_PASSWORD)"
    echo ""
    echo "示例:"
    echo "  bash deploy/docker/push-to-registry.sh backend"
    echo "  bash deploy/docker/push-to-registry.sh models --tag v1.0.0"
    echo ""
}

# ============================================================================
# 本地镜像名 → 远程镜像名 映射
# ============================================================================
get_local_image() {
    case "$1" in
        backend)  echo "tianshu-backend:latest" ;;
        frontend) echo "tianshu-frontend:latest" ;;
        models)   echo "tianshu-models:latest" ;;
        rustfs)   echo "rustfs/rustfs:latest" ;;
        *)        echo "" ;;
    esac
}

get_remote_image() {
    case "$1" in
        backend)  echo "$REGISTRY_PREFIX/tianshu-backend:$TAG" ;;
        frontend) echo "$REGISTRY_PREFIX/tianshu-frontend:$TAG" ;;
        models)   echo "$REGISTRY_PREFIX/tianshu-models:$TAG" ;;
        rustfs)   echo "$REGISTRY_PREFIX/rustfs:$TAG" ;;
        *)        echo "" ;;
    esac
}

# ============================================================================
# 主流程
# ============================================================================

# 解析参数
IMAGE_TYPE=""
TAG="latest"

while [[ $# -gt 0 ]]; do
    case "$1" in
        backend|frontend|models|rustfs) IMAGE_TYPE="$1"; shift ;;
        --tag)     TAG="$2"; shift 2 ;;
        --tag=*)   TAG="${1#*=}"; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *)         log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

if [ -z "$IMAGE_TYPE" ]; then
    log_error "Missing IMAGE_TYPE!"
    show_usage
    exit 1
fi

# 加载 .env
load_env

if [ -z "$REGISTRY_PREFIX" ]; then
    log_error "REGISTRY_PREFIX not set! Check .env file."
    exit 1
fi

LOCAL_IMAGE=$(get_local_image "$IMAGE_TYPE")
REMOTE_IMAGE=$(get_remote_image "$IMAGE_TYPE")

# 检查本地镜像是否存在
if ! docker image inspect "$LOCAL_IMAGE" &> /dev/null; then
    log_error "Local image not found: $LOCAL_IMAGE"
    log_info "Please build it first:"
    case "$IMAGE_TYPE" in
        backend)  log_info "  bash deploy/docker/build.sh --backend-only" ;;
        frontend) log_info "  bash deploy/docker/build.sh --frontend-only" ;;
        models)   log_info "  bash deploy/docker/build.sh --models-only" ;;
        rustfs)   log_info "  docker pull rustfs/rustfs:latest" ;;
    esac
    exit 1
fi

echo ""
log_info "=========================================="
log_info "📤 Push: $IMAGE_TYPE"
log_info "=========================================="
log_info "Local:  $LOCAL_IMAGE"
log_info "Remote: $REMOTE_IMAGE"
echo ""

# 步骤 1: 登录
REGISTRY_HOST=$(echo "$REGISTRY_PREFIX" | cut -d'/' -f1)

if [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
    log_info "步骤 1/3: 登录 $REGISTRY_HOST ..."
    echo "$REGISTRY_PASSWORD" | docker login --username="$REGISTRY_USERNAME" --password-stdin "$REGISTRY_HOST"
    if [ $? -ne 0 ]; then
        log_error "登录失败！"
        exit 1
    fi
    log_success "登录成功"
else
    log_warning "步骤 1/3: 未配置账号密码，跳过登录（确保已手动登录）"
fi
echo ""

# 步骤 2: Tag
log_info "步骤 2/3: 标记镜像..."
docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"
log_success "Tagged: $REMOTE_IMAGE"
echo ""

# 步骤 3: Push
log_info "步骤 3/3: 推送镜像..."
docker push "$REMOTE_IMAGE"
echo ""

log_success "=========================================="
log_success "✅ 推送成功！"
log_success "=========================================="
echo ""
log_info "镜像地址: $REMOTE_IMAGE"
echo ""
