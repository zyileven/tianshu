#!/bin/bash
# Tianshu 指定文件上传脚本
# 用于增量更新，只上传指定的文件到服务器

set -e

# ============================================================================
# 配置
# ============================================================================
SERVER_USER="${1}"
SERVER_HOST="${2}"
SERVER_PATH="${3}"
FILE_SPEC="${4}"  # 指定要上传的文件: backend, frontend, rustfs, models, config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(dirname "$(dirname "${SCRIPT_DIR}")")/docker-images"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# 使用说明
# ============================================================================
show_usage() {
    echo "Usage: $0 <server_user> <server_host> <server_path> <file_spec>"
    echo ""
    echo "Arguments:"
    echo "  server_user   Server username (required)"
    echo "  server_host   Server hostname or IP (required)"
    echo "  server_path   Remote directory path (required)"
    echo "  file_spec     File specification (required)"
    echo ""
    echo "File Specification:"
    echo "  backend-deps  【增量流程初始化】上传依赖层镜像并加载 (tianshu-backend-deps-amd64.tar.gz, ~10GB)"
    echo "                只需做一次，之后代码更新用 backend-code 即可"
    echo "  backend-code  【日常代码更新】上传代码包，在服务器上 build+重启 (tianshu-backend-code-update.tar.gz, <10MB)"
    echo "                前提：服务器已加载 tianshu-backend-deps:latest"
    echo "  backend       全量后端镜像 (tianshu-backend-amd64.tar.gz，用于首次部署或依赖变更)"
    echo "  frontend      前端镜像 (tianshu-frontend-amd64.tar.gz)"
    echo "  rustfs        RustFS 镜像 (rustfs-amd64.tar.gz)"
    echo "  models        模型文件 (models-offline.tar.gz)"
    echo "  config        配置文件 (.env.example, docker-compose.yml 等)"
    echo ""
    echo "Examples:"
    echo "  # 【推荐】日常代码更新（先 build-offline.sh --code-only）"
    echo "  $0 root 192.168.1.100 /opt/tianshu backend-code"
    echo ""
    echo "  # 首次切换到增量更新流程（先 build-offline.sh --deps-only）"
    echo "  $0 root 192.168.1.100 /opt/tianshu backend-deps"
    echo ""
    echo "  # 首次全量部署（先 build-offline.sh）"
    echo "  $0 root 192.168.1.100 /opt/tianshu backend"
    echo ""
    echo "  # 其他"
    echo "  $0 root 192.168.1.100 /opt/tianshu frontend"
    echo "  $0 root 192.168.1.100 /opt/tianshu config"
    echo "  $0 root 192.168.1.100 /opt/tianshu models"
    echo ""
}

# ============================================================================
# 检查参数
# ============================================================================
check_arguments() {
    if [ -z "$SERVER_USER" ] || [ -z "$SERVER_HOST" ] || [ -z "$SERVER_PATH" ] || [ -z "$FILE_SPEC" ]; then
        log_error "缺少必需参数！"
        echo ""
        show_usage
        exit 1
    fi

    # 验证 file_spec
    case "$FILE_SPEC" in
        backend-deps|backend-code|backend|frontend|rustfs|models|config)
            ;;
        *)
            log_error "无效的文件规格: $FILE_SPEC"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# ============================================================================
# 获取文件信息
# ============================================================================
get_file_info() {
    local file_spec=$1

    case "$file_spec" in
        backend-deps)
            echo "tianshu-backend-deps-amd64.tar.gz"
            ;;
        backend-code)
            echo "tianshu-backend-code-update.tar.gz"
            ;;
        backend)
            echo "tianshu-backend-amd64.tar.gz"
            ;;
        frontend)
            echo "tianshu-frontend-amd64.tar.gz"
            ;;
        rustfs)
            echo "rustfs-amd64.tar.gz"
            ;;
        models)
            echo "models-offline.tar.gz"
            ;;
        config)
            echo "config_files"  # 特殊标记
            ;;
    esac
}

# ============================================================================
# 上传文件
# ============================================================================
upload_file() {
    local file_spec=$1
    local file_info=$(get_file_info "$file_spec")

    if [ "$file_info" = "config_files" ]; then
        # 上传配置文件
        log_info "上传配置文件..."

        local config_files=""
        [ -f "${LOCAL_DIR}/.env.example" ] && config_files="${config_files} ${LOCAL_DIR}/.env.example"
        [ -f "${LOCAL_DIR}/docker-compose.yml" ] && config_files="${config_files} ${LOCAL_DIR}/docker-compose.yml"
        [ -f "${LOCAL_DIR}/docker-compose.offline.yml" ] && config_files="${config_files} ${LOCAL_DIR}/docker-compose.offline.yml"
        [ -f "${LOCAL_DIR}/deploy-offline.sh" ] && config_files="${config_files} ${LOCAL_DIR}/deploy-offline.sh"
        [ -d "${LOCAL_DIR}/mcp_config.example.json" ] && config_files="${config_files} ${LOCAL_DIR}/mcp_config.example.json"

        if [ -z "$config_files" ]; then
            log_error "没有找到配置文件！"
            exit 1
        fi

        log_info "使用 rsync 上传配置文件..."
        rsync -avz --progress ${config_files} "${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/"

    else
        # 上传单个镜像文件
        local file_path="${LOCAL_DIR}/${file_info}"

        if [ ! -f "$file_path" ]; then
            log_error "文件不存在: $file_path"
            exit 1
        fi

        log_info "文件信息:"
        ls -lh "$file_path"
        echo ""

        log_info "使用 rsync 上传文件..."
        rsync -avz --progress "$file_path" "${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/"
    fi

    log_success "上传完成"
}

# ============================================================================
# 在服务器上操作
# ============================================================================
server_operations() {
    local file_spec=$1
    local file_info=$(get_file_info "$file_spec")

    echo ""
    log_info "📋 请在服务器上手动执行以下命令："
    echo ""

    case "$file_spec" in
        backend-deps)
            log_info "加载依赖层镜像（无需重启服务，约 5-10 分钟）："
            echo ""
            echo "  cd ${SERVER_PATH}"
            echo "  sudo docker load < ${file_info}"
            echo "  rm -f ${file_info}"
            echo ""
            log_info "完成后即可使用 backend-code 进行日常代码更新："
            echo ""
            echo "  bash deploy/docker/build-offline.sh --code-only"
            echo "  bash deploy/docker/upload-spec-to-server.sh ${SERVER_USER} ${SERVER_HOST} ${SERVER_PATH} backend-code"
            ;;

        backend-code)
            log_info "构建新镜像并重启服务（在 ${SERVER_PATH} 下执行，约 1-2 分钟）："
            echo ""
            echo "  rm -rf /tmp/tianshu-update && mkdir -p /tmp/tianshu-update"
            echo "  tar xzf ${file_info} -C /tmp/tianshu-update/"
            echo "  sudo docker build -f /tmp/tianshu-update/Dockerfile.code -t tianshu-backend:latest /tmp/tianshu-update/"
            echo "  sudo docker-compose up -d --no-deps backend worker"
            echo "  rm -rf /tmp/tianshu-update ${file_info}"
            ;;

        backend)
            log_info "加载镜像并重启后端服务："
            echo ""
            echo "  cd ${SERVER_PATH}"
            echo "  sudo docker load < ${file_info}"
            echo "  sudo docker-compose up -d --no-deps backend worker"
            echo "  rm -f ${file_info}"
            ;;

        frontend)
            log_info "加载镜像并重启前端服务："
            echo ""
            echo "  cd ${SERVER_PATH}"
            echo "  sudo docker load < ${file_info}"
            echo "  sudo docker-compose restart frontend"
            echo "  rm -f ${file_info}"
            ;;

        rustfs)
            log_info "加载镜像并重启对象存储服务："
            echo ""
            echo "  cd ${SERVER_PATH}"
            echo "  sudo docker load < ${file_info}"
            echo "  sudo docker-compose restart rustfs"
            echo "  rm -f ${file_info}"
            ;;

        models)
            log_info "更新模型文件并重启 worker："
            echo ""
            echo "  cd ${SERVER_PATH}"
            echo "  rm -rf models-offline"
            echo "  tar xzf models-offline.tar.gz"
            echo "  sudo docker-compose exec -T worker rm -f /root/.cache/.models_initialized"
            echo "  sudo docker-compose restart worker"
            ;;

        config)
            log_info "配置文件已上传，如修改了 .env 或 docker-compose.yml 需重启服务："
            echo ""
            echo "  cd ${SERVER_PATH}"
            echo "  sudo docker-compose down && sudo docker-compose up -d"
            ;;
    esac
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    log_info "=========================================="
    log_info "📤 Uploading Specific File to Server"
    log_info "=========================================="
    echo ""

    # 检查参数
    check_arguments

    # 显示配置
    log_info "配置信息:"
    echo "  本地目录: ${LOCAL_DIR}"
    echo "  服务器: ${SERVER_USER}@${SERVER_HOST}"
    echo "  远程路径: ${SERVER_PATH}"
    echo "  文件类型: ${FILE_SPEC}"
    echo ""

    # 上传文件
    upload_file "$FILE_SPEC"
    echo ""

    # 服务器操作
    server_operations "$FILE_SPEC"
    echo ""

    # 完成
    log_info "=========================================="
    log_success "✅ Upload Complete!"
    log_info "=========================================="
    echo ""

    log_info "📋 查看服务状态:"
    echo "  ssh ${SERVER_USER}@${SERVER_HOST} 'cd ${SERVER_PATH} && docker-compose ps'"
    echo ""

    log_info "📋 查看服务日志:"
    echo "  ssh ${SERVER_USER}@${SERVER_HOST} 'cd ${SERVER_PATH} && docker-compose logs -f ${FILE_SPEC}'"
    echo ""
}

# 捕获中断信号
trap 'log_warning "上传被用户中断"; exit 130' SIGINT SIGTERM

# 检查帮助参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_usage
    exit 0
fi

# 执行主函数
main
