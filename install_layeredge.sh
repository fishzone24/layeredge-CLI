#!/bin/bash

# LayerEdge CLI Light Node 一键安装脚本
# 此脚本将自动安装并配置LayerEdge CLI Light Node

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}[STEP]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查并安装依赖
install_dependencies() {
    log_step "检查并安装系统依赖"
    
    # 更新包列表
    log_info "更新包列表..."
    apt-get update -y || { log_error "无法更新包列表"; exit 1; }
    
    # 安装基本工具
    log_info "安装基本工具..."
    apt-get install -y curl wget git build-essential pkg-config libssl-dev || { log_error "安装基本工具失败"; exit 1; }
    
    # 检查并安装Go
    if ! check_command go; then
        log_info "安装Go..."
        # 安装Go 1.21.0版本，支持slices包
        wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz -O go.tar.gz || { log_error "下载Go失败"; exit 1; }
        rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz || { log_error "解压Go失败"; exit 1; }
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.profile
        source $HOME/.profile
        rm go.tar.gz
        log_info "Go安装完成: $(go version)"
    else
        # 检查已安装的Go版本
        GO_VERSION=$(go version | grep -oP 'go\d+\.\d+\.\d+' | grep -oP '\d+\.\d+\.\d+')
        GO_MAJOR=$(echo $GO_VERSION | cut -d. -f1)
        GO_MINOR=$(echo $GO_VERSION | cut -d. -f2)
        
        if [ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 21 ]; then
            log_warn "检测到Go版本($GO_VERSION)低于1.21，LayerEdge需要Go 1.21+版本"
            log_info "正在更新Go..."
            wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz -O go.tar.gz || { log_error "下载Go失败"; exit 1; }
            rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz || { log_error "解压Go失败"; exit 1; }
            echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.profile
            source $HOME/.profile
            rm go.tar.gz
            log_info "Go更新完成: $(go version)"
        else
            log_info "Go已安装且版本满足要求: $(go version)"
        fi
    fi
    
    # 检查并安装Rust
    if ! check_command rustc; then
        log_info "安装Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || { log_error "安装Rust失败"; exit 1; }
        source $HOME/.cargo/env
        log_info "Rust安装完成: $(rustc --version)"
    else
        log_info "Rust已安装: $(rustc --version)"
    fi
    
    # 安装Risc0工具链
    log_info "安装Risc0工具链..."
    curl -L https://risczero.com/install | bash || { log_error "安装Risc0脚本下载失败"; exit 1; }
    
    # 确保rzup命令在PATH中
    export PATH="$HOME/.risc0/bin:$PATH"
    
    # 加载环境变量
    if [ -f "$HOME/.bashrc" ]; then
        source $HOME/.bashrc
    fi
    if [ -f "$HOME/.cargo/env" ]; then
        source $HOME/.cargo/env
    fi
    
    # 安装risc0工具链
    if ! check_command rzup; then
        log_error "rzup命令未找到，请确保安装脚本正确执行"
        log_info "尝试手动安装risc0工具链..."
        if [ -f "$HOME/.risc0/bin/rzup" ]; then
            $HOME/.risc0/bin/rzup install || { log_error "Risc0工具链安装失败"; exit 1; }
        else
            log_error "找不到rzup工具，Risc0安装失败"; exit 1;
        fi
    else
        log_info "执行rzup install..."
        rzup install || { log_error "Risc0工具链安装失败"; exit 1; }
    fi
    
    # 设置risc0环境变量
    export RISC0_TOOLCHAIN_PATH="$HOME/.risc0/toolchain"
    echo 'export PATH="$HOME/.risc0/bin:$PATH"' >> $HOME/.profile
    echo 'export RISC0_TOOLCHAIN_PATH="$HOME/.risc0/toolchain"' >> $HOME/.profile
    
    log_info "所有依赖安装完成"
}

# 克隆仓库
clone_repository() {
    log_step "克隆Light Node仓库"
    
    if [ -d "light-node" ]; then
        log_warn "light-node目录已存在，将删除并重新克隆"
        rm -rf light-node || { log_error "删除light-node目录失败"; exit 1; }
    fi
    
    git clone https://github.com/Layer-Edge/light-node.git || { log_error "克隆仓库失败"; exit 1; }
    log_info "仓库克隆成功"
    
    cd light-node
}

# 配置环境变量
configure_environment() {
    log_step "配置环境变量"
    
    # 获取Merkle服务端口，如果未设置则使用默认值3001
    local merkle_port=${MERKLE_PORT:-3001}
    
    # 创建配置文件
    cat > .env << EOL
GRPC_URL=34.31.74.109:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:${merkle_port}
# 或者使用: ZK_PROVER_URL=https://layeredge.mintair.xyz/
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='cli-node-private-key'
EOL
    
    log_info "环境变量配置文件已创建: .env"
    log_warn "请编辑.env文件，设置您的PRIVATE_KEY和其他必要的环境变量"
    log_info "您可以使用以下命令编辑: nano .env"
}

# 检查端口是否被占用
check_port_usage() {
    local port=$1
    if command -v netstat &> /dev/null; then
        netstat -tuln | grep -q ":$port "
        return $?
    elif command -v ss &> /dev/null; then
        ss -tuln | grep -q ":$port "
        return $?
    elif command -v lsof &> /dev/null; then
        lsof -i:$port -sTCP:LISTEN &>/dev/null
        return $?
    else
        # 如果以上命令都不可用，尝试通过尝试绑定端口来检查
        (echo > /dev/tcp/127.0.0.1/$port) &>/dev/null
        if [ $? -eq 0 ]; then
            return 1  # 端口可用
        else
            return 0  # 端口被占用
        fi
    fi
}

# 启动Merkle服务
start_merkle_service() {
    log_step "启动Merkle服务"
    
    # 确保环境变量正确设置
    export PATH="$HOME/.risc0/bin:$PATH"
    export RISC0_TOOLCHAIN_PATH="$HOME/.risc0/toolchain"
    
    # 默认端口
    MERKLE_PORT=3001
    
    # 检查端口是否被占用
    if check_port_usage $MERKLE_PORT; then
        log_warn "端口 $MERKLE_PORT 已被占用"
        
        # 显示占用端口的进程信息
        log_info "正在查找占用端口 $MERKLE_PORT 的进程..."
        PID_INFO=""
        
        if command -v lsof &> /dev/null; then
            PID_INFO=$(lsof -i:$MERKLE_PORT -sTCP:LISTEN -t 2>/dev/null)
        elif command -v netstat &> /dev/null; then
            PID_INFO=$(netstat -tuln | grep ":$MERKLE_PORT " | awk '{print $7}' | cut -d'/' -f1 2>/dev/null)
        elif command -v ss &> /dev/null; then
            PID_INFO=$(ss -tuln | grep ":$MERKLE_PORT " | awk '{print $7}' 2>/dev/null)
        fi
        
        if [ -n "$PID_INFO" ]; then
            log_info "发现占用端口 $MERKLE_PORT 的进程 PID: $PID_INFO"
            if command -v ps &> /dev/null; then
                log_info "进程详情:"
                ps -p $PID_INFO -o pid,ppid,cmd 2>/dev/null || ps $PID_INFO 2>/dev/null
            fi
            
            log_info "您希望如何处理?"
            log_info "1. 终止占用端口 $MERKLE_PORT 的进程并继续安装"
            log_info "2. 使用其他端口"
            log_info "请输入选项 (1 或 2):"
            
            read PORT_CHOICE
            
            if [ "$PORT_CHOICE" = "1" ]; then
                log_warn "正在终止进程 PID: $PID_INFO..."
                kill -9 $PID_INFO 2>/dev/null
                sleep 2
                
                # 再次检查端口是否已释放
                if check_port_usage $MERKLE_PORT; then
                    log_error "无法释放端口 $MERKLE_PORT，将尝试使用其他端口"
                    log_info "请输入一个新的端口号 (推荐范围: 3002-3999):"
                    read NEW_PORT
                else
                    log_info "端口 $MERKLE_PORT 已成功释放，将继续使用此端口"
                    MERKLE_PORT=3001
                fi
            else
                log_info "请输入一个新的端口号 (推荐范围: 3002-3999):"
                read NEW_PORT
            fi
        else
            log_warn "无法获取占用端口 $MERKLE_PORT 的进程信息"
            log_info "请输入一个新的端口号 (推荐范围: 3002-3999):"
            read NEW_PORT
        fi
        
        # 如果需要使用新端口，验证输入是否有效
        if [ -n "$NEW_PORT" ]; then
            # 验证输入是否为有效端口号
            if [[ ! $NEW_PORT =~ ^[0-9]+$ ]] || [ $NEW_PORT -lt 1024 ] || [ $NEW_PORT -gt 65535 ]; then
                log_error "无效的端口号，端口必须是1024-65535之间的数字"
                exit 1
            fi
            
            # 检查新端口是否也被占用
            if check_port_usage $NEW_PORT; then
                log_error "新端口 $NEW_PORT 也被占用，请尝试其他端口或手动释放端口"
                exit 1
            fi
            
            MERKLE_PORT=$NEW_PORT
            log_info "将使用新端口: $MERKLE_PORT"
        fi
    else
        log_info "端口 $MERKLE_PORT 可用"
    fi
    
    # 检查目录是否存在
    if [ ! -d "risc0-merkle-service" ]; then
        log_error "risc0-merkle-service目录不存在，请确保仓库克隆正确"
        exit 1
    fi
    
    cd risc0-merkle-service
    log_info "构建Merkle服务..."
    
    # 显示当前环境变量和系统信息，帮助调试
    log_info "当前RISC0_TOOLCHAIN_PATH: $RISC0_TOOLCHAIN_PATH"
    log_info "当前PATH: $PATH"
    log_info "系统信息: $(uname -a)"
    log_info "检查risc0工具链是否可用..."
    
    # 检查rzup命令
    if ! check_command rzup; then
        log_warn "rzup命令未找到，尝试从.risc0/bin目录直接使用"
        if [ -f "$HOME/.risc0/bin/rzup" ]; then
            log_info "找到rzup: $HOME/.risc0/bin/rzup"
            $HOME/.risc0/bin/rzup --version || log_warn "rzup版本检查失败"
        else
            log_error "rzup命令未找到，请确保risc0工具链已正确安装"
            exit 1
        fi
    else
        log_info "rzup版本: $(rzup --version 2>&1 || echo '无法获取版本')"
    fi
    
    # 检查cargo命令
    if ! check_command cargo; then
        log_error "cargo命令未找到，请确保Rust已正确安装"
        exit 1
    else
        log_info "Cargo版本: $(cargo --version)"
    fi
    
    # 构建前清理
    log_info "清理之前的构建..."
    cargo clean
    
    # 构建服务
    log_info "构建Merkle服务..."
    cargo build --verbose || { log_error "构建Merkle服务失败"; exit 1; }
    
    # 检查是否有旧的进程在运行
    if [ -f "merkle-service.pid" ]; then
        OLD_PID=$(cat merkle-service.pid)
        if ps -p $OLD_PID > /dev/null; then
            log_warn "发现旧的Merkle服务进程(PID: $OLD_PID)，正在停止..."
            kill $OLD_PID 2>/dev/null || log_warn "无法停止旧进程，可能需要手动终止"
            sleep 2
        fi
    fi
    
    # 启动服务
    log_info "启动Merkle服务(端口: $MERKLE_PORT)..."
    log_warn "Merkle服务将在后台运行，日志将输出到merkle-service.log"
    
    # 使用更详细的日志记录
    echo "启动时间: $(date)" > merkle-service.log
    echo "环境变量: RISC0_TOOLCHAIN_PATH=$RISC0_TOOLCHAIN_PATH" >> merkle-service.log
    echo "系统信息: $(uname -a)" >> merkle-service.log
    echo "使用端口: $MERKLE_PORT" >> merkle-service.log
    
    # 启动服务并重定向所有输出，使用指定端口
    MERKLE_SERVICE_PORT=$MERKLE_PORT nohup cargo run --verbose > merkle-service.log 2>&1 &
    MERKLE_PID=$!
    echo $MERKLE_PID > merkle-service.pid
    
    log_info "Merkle服务进程已启动(PID: $MERKLE_PID)，等待服务初始化..."
    
    # 增加等待时间并添加进度指示
    WAIT_TIME=30
    for i in $(seq 1 $WAIT_TIME); do
        if ! ps -p $MERKLE_PID > /dev/null; then
            log_error "Merkle服务进程已终止，启动失败"
            log_info "查看日志内容:"
            tail -n 20 merkle-service.log
            exit 1
        fi
        
        # 每5秒检查一次日志中是否有成功启动的标志
        if [ $((i % 5)) -eq 0 ]; then
            if grep -q "Listening on" merkle-service.log 2>/dev/null; then
                log_info "Merkle服务已成功启动，监听端口已打开"
                break
            fi
            log_info "等待中... $i/$WAIT_TIME 秒"
        fi
        sleep 1
    done
    
    # 最终检查
    if ps -p $MERKLE_PID > /dev/null; then
        # 检查日志中是否有错误信息
        if grep -i "error\|panic\|failed" merkle-service.log; then
            log_warn "Merkle服务进程正在运行，但日志中发现错误信息，请检查"
            log_info "最近的日志内容:"
            tail -n 10 merkle-service.log
        else
            log_info "Merkle服务已成功启动，PID: $MERKLE_PID"
        fi
    else
        log_error "Merkle服务启动失败，请检查merkle-service.log"
        log_info "日志内容:"
        cat merkle-service.log
        exit 1
    fi
    
    cd ..
}

# 构建并运行Light Node
build_and_run_light_node() {
    log_step "构建并运行LayerEdge Light Node"
    
    # 检查并修复go.mod文件中的Go版本格式
    if [ -f "go.mod" ]; then
        log_info "检查go.mod文件..."
        # 查找并修复go版本行，将类似1.23.1的格式改为1.23
        if grep -q "go 1\..*\..*" go.mod; then
            log_info "修复go.mod文件中的Go版本格式..."
            # 使用sed将go 1.xx.x格式改为go 1.xx
            sed -i -E 's/go ([0-9]+)\.([0-9]+)\.[0-9]+/go \1.\2/g' go.mod
            log_info "go.mod文件已修复"
        fi
    fi
    
    log_info "构建Light Node..."
    
    # 检查并降级不兼容的依赖包
    log_info "检查依赖包版本兼容性..."
    
    # 获取当前Go版本
    GO_VERSION=$(go version | grep -oP 'go\d+\.\d+\.\d+' | grep -oP '\d+\.\d+\.\d+')
    GO_MAJOR=$(echo $GO_VERSION | cut -d. -f1)
    GO_MINOR=$(echo $GO_VERSION | cut -d. -f2)
    
    # 如果Go版本低于1.23，降级需要maps包的依赖
    if [ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 23 ]; then
        log_info "当前Go版本($GO_VERSION)低于1.23，降级需要maps包的依赖..."
        # 降级grpc版本到不需要maps包的版本
        go get google.golang.org/grpc@v1.59.0
    fi
    
    # 如果Go版本低于1.21，降级需要slices包的依赖
    if [ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 21 ]; then
        log_info "当前Go版本($GO_VERSION)低于1.21，降级需要slices包的依赖..."
        # 这里可以添加降级特定依赖的命令
    fi
    
    # 更新go.mod和go.sum
    go mod tidy
    
    # 尝试构建
    go build || { log_error "构建Light Node失败"; exit 1; }
    
    log_info "启动Light Node..."
    log_warn "Light Node将在后台运行，日志将输出到light-node.log"
    nohup ./light-node > light-node.log 2>&1 &
    LIGHT_NODE_PID=$!
    echo $LIGHT_NODE_PID > light-node.pid
    
    if ps -p $LIGHT_NODE_PID > /dev/null; then
        log_info "Light Node已成功启动，PID: $LIGHT_NODE_PID"
    else
        log_error "Light Node启动失败，请检查light-node.log"
        exit 1
    fi
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本"
    
    # 创建停止脚本
    cat > stop_layeredge.sh << 'EOL'
#!/bin/bash
set -e

if [ -f "light-node.pid" ]; then
    PID=$(cat light-node.pid)
    if ps -p $PID > /dev/null; then
        echo "停止Light Node (PID: $PID)..."
        kill $PID
        echo "Light Node已停止"
    else
        echo "Light Node不在运行状态"
    fi
    rm light-node.pid
fi

if [ -f "risc0-merkle-service/merkle-service.pid" ]; then
    PID=$(cat risc0-merkle-service/merkle-service.pid)
    if ps -p $PID > /dev/null; then
        echo "停止Merkle服务 (PID: $PID)..."
        kill $PID
        echo "Merkle服务已停止"
    else
        echo "Merkle服务不在运行状态"
    fi
    rm risc0-merkle-service/merkle-service.pid
fi
EOL
    chmod +x stop_layeredge.sh
    
    # 创建重启脚本
    cat > restart_layeredge.sh << 'EOL'
#!/bin/bash
set -e

echo "重启LayerEdge服务..."

# 停止服务
./stop_layeredge.sh

# 获取当前配置的端口号
if [ -f ".env" ]; then
    MERKLE_PORT=$(grep -oP 'ZK_PROVER_URL=http://127.0.0.1:\K[0-9]+' .env || echo "3001")
else
    MERKLE_PORT=3001
fi

# 检查端口是否被占用
check_port_usage() {
    local port=$1
    if command -v netstat &> /dev/null; then
        netstat -tuln | grep -q ":$port "
        return $?
    elif command -v ss &> /dev/null; then
        ss -tuln | grep -q ":$port "
        return $?
    elif command -v lsof &> /dev/null; then
        lsof -i:$port -sTCP:LISTEN &>/dev/null
        return $?
    else
        (echo > /dev/tcp/127.0.0.1/$port) &>/dev/null
        if [ $? -eq 0 ]; then
            return 1  # 端口可用
        else
            return 0  # 端口被占用
        fi
    fi
}

# 检查端口是否被占用
if check_port_usage $MERKLE_PORT; then
    echo "警告: 端口 $MERKLE_PORT 已被占用"
    echo "请输入一个新的端口号 (推荐范围: 3002-3999):"
    read -p "新端口号 > " NEW_PORT
    
    # 验证输入是否为有效端口号
    if [[ ! $NEW_PORT =~ ^[0-9]+$ ]] || [ $NEW_PORT -lt 1024 ] || [ $NEW_PORT -gt 65535 ]; then
        echo "错误: 无效的端口号，端口必须是1024-65535之间的数字"
        exit 1
    fi
    
    # 检查新端口是否也被占用
    if check_port_usage $NEW_PORT; then
        echo "错误: 新端口 $NEW_PORT 也被占用，请尝试其他端口或手动释放端口"
        exit 1
    fi
    
    MERKLE_PORT=$NEW_PORT
    echo "将使用新端口: $MERKLE_PORT"
    
    # 更新.env文件中的端口
    if [ -f ".env" ]; then
        sed -i "s|ZK_PROVER_URL=http://127.0.0.1:[0-9]\+|ZK_PROVER_URL=http://127.0.0.1:$MERKLE_PORT|g" .env
        echo "已更新.env文件中的端口配置"
    fi
fi

# 启动Merkle服务
cd risc0-merkle-service
echo "启动Merkle服务(端口: $MERKLE_PORT)..."
MERKLE_SERVICE_PORT=$MERKLE_PORT nohup cargo run > merkle-service.log 2>&1 &
MERKLE_PID=$!
echo $MERKLE_PID > merkle-service.pid
echo "Merkle服务已启动，PID: $MERKLE_PID"
cd ..

# 等待Merkle服务初始化
echo "等待Merkle服务初始化..."
sleep 10

# 启动Light Node
echo "启动Light Node..."
nohup ./light-node > light-node.log 2>&1 &
LIGHT_NODE_PID=$!
echo $LIGHT_NODE_PID > light-node.pid
echo "Light Node已启动，PID: $LIGHT_NODE_PID"

echo "LayerEdge服务已重启"
EOL
    chmod +x restart_layeredge.sh
    
    # 创建状态检查脚本
    cat > status_layeredge.sh << 'EOL'
#!/bin/bash

check_service() {
    local pid_file=$1
    local service_name=$2
    local log_file=$3
    
    if [ -f "$pid_file" ]; then
        PID=$(cat $pid_file)
        if ps -p $PID > /dev/null; then
            echo -e "${GREEN}✓${NC} $service_name 正在运行 (PID: $PID)"
            
            # 检查日志中是否有错误
            if [ -f "$log_file" ] && grep -q -i "error\|panic\|failed\|exception" "$log_file"; then
                echo -e "${YELLOW}!${NC} 警告: $service_name 日志中发现错误信息，请检查 $log_file"
            fi
            return 0
        else
            echo -e "${RED}✗${NC} $service_name 不在运行状态，但PID文件存在"
            if [ -f "$log_file" ]; then
                echo -e "${YELLOW}!${NC} 最近的日志内容 ($log_file):"
                tail -n 5 "$log_file"
            fi
            return 1
        fi
    else
        echo -e "${RED}✗${NC} $service_name 未启动 (PID文件不存在)"
        return 1
    fi
}

echo "LayerEdge服务状态:"
echo "-------------------"

check_service "risc0-merkle-service/merkle-service.pid" "Merkle服务" "risc0-merkle-service/merkle-service.log"
check_service "light-node.pid" "Light Node" "light-node.log"

echo "\n日志文件:"
echo "-------------------"
echo "Merkle服务日志: risc0-merkle-service/merkle-service.log"
echo "Light Node日志: light-node.log"

echo "\n使用以下命令查看日志:"
echo "tail -f risc0-merkle-service/merkle-service.log"
echo "tail -f light-node.log"
EOL
    chmod +x status_layeredge.sh
    
    log_info "管理脚本已创建:"
    log_info "  - stop_layeredge.sh: 停止所有服务"
    log_info "  - restart_layeredge.sh: 重启所有服务"
    log_info "  - status_layeredge.sh: 检查服务状态"
}

# 显示使用说明
show_instructions() {
    log_step "安装完成"
    
    echo -e "${GREEN}LayerEdge CLI Light Node已成功安装!${NC}"
    echo -e "\n${YELLOW}重要说明:${NC}"
    echo -e "1. 请编辑.env文件设置您的私钥: ${BLUE}nano .env${NC}"
    echo -e "2. 使用以下命令管理服务:"
    echo -e "   - 检查状态: ${BLUE}./status_layeredge.sh${NC}"
    echo -e "   - 停止服务: ${BLUE}./stop_layeredge.sh${NC}"
    echo -e "   - 重启服务: ${BLUE}./restart_layeredge.sh${NC}"
    echo -e "3. 查看日志:"
    echo -e "   - Merkle服务: ${BLUE}tail -f risc0-merkle-service/merkle-service.log${NC}"
    echo -e "   - Light Node: ${BLUE}tail -f light-node.log${NC}"
    echo -e "\n${YELLOW}连接到LayerEdge Dashboard:${NC}"
    echo -e "1. 访问 ${BLUE}dashboard.layeredge.io${NC}"
    echo -e "2. 连接您的钱包"
    echo -e "3. 链接您的CLI节点公钥"
    echo -e "\n${YELLOW}获取CLI节点积分:${NC}"
    echo -e "${BLUE}https://light-node.layeredge.io/api/cli-node/points/{walletAddress}${NC}"
    echo -e "将{walletAddress}替换为您的实际CLI钱包地址"
    echo -e "\n${GREEN}祝您使用愉快!${NC}"
}

# 主函数
main() {
    log_step "开始安装LayerEdge CLI Light Node"
    
    # 检查是否为root用户
    # 自动获取root权限
    if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" "$@"
        exit $?
    fi
    
    # 执行安装步骤
    install_dependencies
    clone_repository
    start_merkle_service
    configure_environment
    build_and_run_light_node
    create_management_scripts
    show_instructions
}

# 执行主函数
main