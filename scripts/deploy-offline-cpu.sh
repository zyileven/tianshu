#!/bin/bash
# Tianshu CPU 模式离线部署脚本
# 适用于 Mac 和无 GPU 的环境
# 用于在生产环境（离线）中部署 Tianshu（CPU 模式）

set -e

# ============================================================================
# 配置
# ============================================================================
COMPOSE_FILE="docker-compose.cpu.yml"
DEVICE_MODE="cpu"

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
# 检查函数
# ============================================================================
check_docker() {
    log_info "Checking Docker..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker not found!"
        log_info "Please install Docker Desktop for Mac:"
        log_info "  https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    if ! docker ps &> /dev/null; then
        log_error "Docker daemon is not running!"
        log_info "Please start Docker Desktop"
        exit 1
    fi

    log_success "Docker is running"
    echo ""
}

check_platform() {
    log_info "Checking platform..."

    ARCH=$(uname -m)
    OS=$(uname -s)

    log_info "  OS: $OS"
    log_info "  Architecture: $ARCH"

    if [ "$ARCH" = "arm64" ]; then
        log_warning "Detected ARM64 (Apple Silicon)"
        log_info "  Docker images are amd64 and will run via Rosetta 2"
        log_info "  Performance may be slower than native ARM64"

        # 检查 Rosetta 2 是否启用
        if [ "$OS" = "Darwin" ]; then
            if ! docker run --rm --platform linux/amd64 hello-world &> /dev/null 2>&1; then
                log_error "Cannot run amd64 containers!"
                log_info "Please enable Rosetta 2 emulation in Docker Desktop:"
                log_info "  Settings > General > Use Virtualization framework > Use Rosetta for x86_64/amd64 emulation"
                exit 1
            fi
            log_success "Rosetta 2 emulation is enabled"
        fi
    fi
    echo ""
}

check_files() {
    log_info "Checking required files..."

    local missing_files=()

    if [ ! -f "tianshu-backend-amd64.tar.gz" ]; then
        missing_files+=("tianshu-backend-amd64.tar.gz")
    fi

    if [ ! -f "tianshu-frontend-amd64.tar.gz" ]; then
        missing_files+=("tianshu-frontend-amd64.tar.gz")
    fi

    if [ ! -f "rustfs-amd64.tar.gz" ]; then
        missing_files+=("rustfs-amd64.tar.gz")
    fi

    if [ ! -f "models-offline.tar.gz" ] && [ ! -L "models-offline.tar.gz" ]; then
        log_warning "models-offline.tar.gz not found"
        missing_files+=("models-offline.tar.gz")
    fi

    if [ ${#missing_files[@]} -ne 0 ]; then
        log_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        echo ""
        log_error "Please ensure all files are transferred to this directory"
        exit 1
    fi

    log_success "All required files found"
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    log_info "=========================================="
    log_info "🚀 Deploying Tianshu in CPU Mode (Offline)"
    log_info "=========================================="
    echo ""

    # 1. 检查 Docker
    check_docker

    # 2. 检查平台
    check_platform

    # 3. 检查文件
    check_files
    echo ""

    # 4. 加载 Docker 镜像
    log_info "📥 Loading Docker images..."
    log_info "   This may take 5-10 minutes..."
    echo ""

    log_info "   Loading backend unified image..."
    docker load < tianshu-backend-amd64.tar.gz

    log_info "   Loading frontend image..."
    docker load < tianshu-frontend-amd64.tar.gz

    log_info "   Loading rustfs image..."
    docker load < rustfs-amd64.tar.gz

    log_success "All images loaded successfully"
    echo ""

    # 5. 解压模型文件
    if [ ! -L "models-offline.tar.gz" ]; then
        if [ ! -d "models-offline" ]; then
            log_info "📦 Extracting models..."
            log_info "   This may take 5-10 minutes..."
            tar xzf models-offline.tar.gz
            log_success "Models extracted successfully"
        else
            log_info "📦 Models directory already exists, skipping extraction"
        fi
    else
        log_info "📦 Models are linked, extracting from source..."
        tar xzf models-offline.tar.gz
        log_success "Models extracted successfully"
    fi
    echo ""

    # 6. 创建目录结构
    log_info "📁 Creating directories..."
    mkdir -p data/{uploads,output,db}
    mkdir -p logs/{backend,worker,mcp}
    log_success "Directories created"
    echo ""

    # 7. 配置环境变量
    if [ ! -f ".env" ]; then
        log_info "⚙️  Creating .env from template..."

        if [ -f ".env.example" ]; then
            cp .env.example .env
        else
            log_error ".env.example not found!"
            log_info "Please create .env manually or copy it from the source"
            exit 1
        fi

        # 生成 JWT 密钥
        if command -v openssl &> /dev/null; then
            JWT_KEY=$(openssl rand -hex 32)
            sed -i.bak "s/your-secret-key-change-in-production/$JWT_KEY/" .env
            rm -f .env.bak
            log_success "JWT secret key generated"
        else
            log_warning "openssl not found, please manually set JWT_SECRET_KEY in .env"
        fi

        # 强制设置 CPU 模式
        if grep -q "DEVICE_MODE=" .env; then
            sed -i.bak "s/DEVICE_MODE=.*/DEVICE_MODE=cpu/" .env
            rm -f .env.bak
        else
            echo "DEVICE_MODE=cpu" >> .env
        fi
        log_success "DEVICE_MODE set to cpu"

        # 设置 RUSTFS_PUBLIC_URL（Mac 本地环境）
        if grep -q "RUSTFS_PUBLIC_URL=" .env; then
            sed -i.bak "s|RUSTFS_PUBLIC_URL=.*|RUSTFS_PUBLIC_URL=http://localhost:9000|" .env
            rm -f .env.bak
        else
            echo "RUSTFS_PUBLIC_URL=http://localhost:9000" >> .env
        fi
        log_success "RUSTFS_PUBLIC_URL set to http://localhost:9000"

        log_success ".env created"
        log_warning "Please review and adjust .env if needed before starting services"
        echo ""
    else
        log_info ".env already exists, skipping creation"

        # 确保 DEVICE_MODE 设置为 cpu
        if grep -q "DEVICE_MODE=" .env; then
            if ! grep -q "DEVICE_MODE=cpu" .env; then
                log_warning "Updating DEVICE_MODE to cpu in existing .env"
                sed -i.bak "s/DEVICE_MODE=.*/DEVICE_MODE=cpu/" .env
                rm -f .env.bak
            fi
        else
            log_warning "Adding DEVICE_MODE=cpu to existing .env"
            echo "DEVICE_MODE=cpu" >> .env
        fi
        echo ""
    fi

    # 8. 启动服务
    log_info "🚀 Starting services in CPU mode..."
    log_info "   Using docker-compose file: $COMPOSE_FILE"
    echo ""

    # 检查 docker-compose 命令
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        log_error "Docker Compose not found!"
        exit 1
    fi

    $COMPOSE_CMD -f $COMPOSE_FILE up -d

    log_success "Services started successfully"
    echo ""

    # 9. 健康检查
    log_info "🔍 Waiting for services to start..."
    log_info "   This may take 2-3 minutes (CPU mode initialization is slower)..."
    echo ""

    for i in {1..60}; do
        if curl -f -s http://localhost:8000/api/v1/health > /dev/null 2>&1; then
            log_success "Backend is healthy"
            break
        fi
        echo -n "."
        sleep 2

        if [ $i -eq 60 ]; then
            echo ""
            log_warning "Backend health check timeout"
            log_info "Services may still be starting, check logs with:"
            log_info "  $COMPOSE_CMD -f $COMPOSE_FILE logs -f backend"
        fi
    done
    echo ""

    # 10. 显示访问信息
    log_info "=========================================="
    log_success "✅ Deployment Complete (CPU Mode)!"
    log_info "=========================================="
    echo ""

    log_info "🌐 Access URLs:"
    echo "   Web UI:     http://localhost"
    echo "   API:        http://localhost:8000"
    echo "   API Docs:   http://localhost:8000/docs"
    echo "   RustFS:     http://localhost:9001"
    echo ""

    log_info "📊 Check status:"
    echo "   $COMPOSE_CMD -f $COMPOSE_FILE ps"
    echo ""

    log_info "📋 View logs:"
    echo "   $COMPOSE_CMD -f $COMPOSE_FILE logs -f"
    echo "   $COMPOSE_CMD -f $COMPOSE_FILE logs -f backend"
    echo "   $COMPOSE_CMD -f $COMPOSE_FILE logs -f worker"
    echo ""

    log_info "🛑 Stop services:"
    echo "   $COMPOSE_CMD -f $COMPOSE_FILE down"
    echo ""

    log_warning "⚠️  Running in CPU Mode:"
    echo "     - Processing will be MUCH slower than GPU mode (5-10x slower)"
    echo "     - Recommended for testing/development only"
    echo "     - For production use, deploy on a server with NVIDIA GPU"
    echo ""

    log_info "💡 Performance Tips:"
    echo "     - Allocate more CPU cores in Docker Desktop (Settings > Resources)"
    echo "     - Allocate more memory (recommend 16GB+)"
    echo "     - Process smaller files for better experience"
    echo ""

    log_info "📝 Next Steps:"
    echo "     1. Open http://localhost in your browser"
    echo "     2. Upload a small test PDF to verify processing"
    echo "     3. Check worker logs if processing seems stuck:"
    echo "        $COMPOSE_CMD -f $COMPOSE_FILE logs -f worker"
    echo ""

    log_success "Deployment script completed!"
}

# 捕获中断信号
trap 'log_warning "Deployment interrupted by user"; exit 130' SIGINT SIGTERM

# 执行主函数
main
