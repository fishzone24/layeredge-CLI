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
    
    # 不进入light-node目录，保持在当前目录
    log_info "仓库已克隆到: $(pwd)/light-node"
}

# 配置环境变量
configure_environment() {
    log_step "配置环境变量"
    
    # 获取Merkle服务端口，如果未设置则使用默认值3001
    local merkle_port=${MERKLE_PORT:-3001}
    
    # 确保在light-node目录中创建配置文件
    if [ ! -d "light-node" ]; then
        log_error "找不到light-node目录，无法创建配置文件"
        return 1
    fi
    
    # 进入light-node目录
    cd light-node
    log_info "进入light-node目录创建配置文件: $(pwd)"
    
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
    
    # 保存当前目录路径，以便后续返回
    ORIGINAL_DIR=$(pwd)
    log_info "保存当前目录: $ORIGINAL_DIR"
    
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
            
            log_info "检测到端口占用，将自动终止占用进程并继续安装"
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
    
    # 返回到原始目录
    cd "$ORIGINAL_DIR"
    log_info "返回到原始目录: $(pwd)"
}

# 构建并运行Light Node
build_and_run_light_node() {
    log_step "构建并运行Light Node"
    
    # 确保在light-node目录中
    # 首先获取当前目录
    CURRENT_DIR=$(pwd)
    log_info "当前目录: $CURRENT_DIR"
    
    # 检查当前目录是否是light-node目录
    if [[ "$CURRENT_DIR" != *"/light-node"* && "$CURRENT_DIR" != *"/light-node/"* ]]; then
        # 如果不是，尝试返回到安装根目录
        cd $HOME
        
        # 检查是否存在light-node目录
        if [ ! -d "light-node" ]; then
            log_error "找不到light-node目录，请确保仓库克隆正确"
            log_info "尝试重新克隆仓库..."
            clone_repository
        fi
    else
        # 如果当前在light-node的子目录中，返回到light-node目录
        while [[ "$(basename $(pwd))" != "light-node" && "$(pwd)" != "/" && "$(pwd)" != "$HOME" ]]; do
            cd ..
        done
    fi
    
    # 最终确认是否在light-node目录中
    if [[ "$(basename $(pwd))" != "light-node" ]]; then
        if [ -d "light-node" ]; then
            cd light-node
        else
            log_error "无法找到light-node目录，请手动检查安装"
            exit 1
        fi
    fi
    
    log_info "进入light-node目录: $(pwd)"
    
    # 构建Light Node
    log_info "开始构建Light Node..."
    go build -o light-node-cli main.go || { log_error "构建Light Node失败"; exit 1; }
    
    log_info "Light Node构建成功"
    
    # 创建systemd服务文件
    log_info "创建systemd服务..."
    
    cat > /etc/systemd/system/layeredge-light-node.service << EOL
[Unit]
Description=LayerEdge Light Node Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/light-node-cli
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOL
    
    # 重新加载systemd配置
    systemctl daemon-reload
    
    # 启动服务
    log_info "启动Light Node服务..."
    systemctl enable layeredge-light-node
    systemctl start layeredge-light-node
    
    # 检查服务状态
    if systemctl is-active --quiet layeredge-light-node; then
        log_info "Light Node服务已成功启动"
    else
        log_warn "Light Node服务启动失败，请检查日志: journalctl -u layeredge-light-node -f"
    fi
}

# 运行交互式管理菜单
run_management_menu() {
    log_step "运行交互式管理菜单"
    
    # 清屏函数
    clear_screen() {
        clear
    }
    
    # 显示标题
    show_header() {
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                LayerEdge CLI 管理工具                      ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo
    }
    
    # 检查服务状态
    check_service_status() {
        if systemctl is-active --quiet layeredge-light-node; then
            echo -e "${GREEN}● 运行中${NC}"
        else
            echo -e "${RED}● 已停止${NC}"
        fi
    }
    
    # 主菜单
clear_screen() {
    clear
}

# 显示标题
show_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                LayerEdge CLI 管理工具                      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet layeredge-light-node; then
        echo -e "${GREEN}● 运行中${NC}"
    else
        echo -e "${RED}● 已停止${NC}"
    fi
}

# 主菜单
show_main_menu() {
    clear_screen
    show_header
    
    echo -e "LayerEdge Light Node 状态: $(check_service_status)"
    echo
    echo -e "${YELLOW}请选择操作:${NC}"
    echo -e "${GREEN}1)${NC} 启动服务"
    echo -e "${GREEN}2)${NC} 停止服务"
    echo -e "${GREEN}3)${NC} 重启服务"
    echo -e "${GREEN}4)${NC} 查看服务状态"
    echo -e "${GREEN}5)${NC} 查看服务日志"
    echo -e "${GREEN}6)${NC} 配置管理"
    echo -e "${GREEN}7)${NC} 系统信息"
    echo -e "${GREEN}8)${NC} 卸载服务"
    echo -e "${GREEN}0)${NC} 退出"
    echo
    echo -n -e "${YELLOW}请输入选项 [0-8]:${NC} "
    read -r choice
    
    case \$choice in
        1) start_service ;;
        2) stop_service ;;
        3) restart_service ;;
        4) show_status ;;
        5) show_logs ;;
        6) config_management ;;
        7) system_info ;;
        8) uninstall_service ;;
        0) exit 0 ;;
        *) 
            echo -e "${RED}无效选项!${NC}"
            sleep 2
            show_main_menu
            ;;
    esac
}

# 启动服务
start_service() {
    clear_screen
    show_header
    echo -e "${BLUE}[操作]${NC} 正在启动 LayerEdge Light Node 服务..."
    
    sudo systemctl start layeredge-light-node
    
    if systemctl is-active --quiet layeredge-light-node; then
        echo -e "${GREEN}[成功]${NC} LayerEdge Light Node 服务已成功启动!"
    else
        echo -e "${RED}[错误]${NC} LayerEdge Light Node 服务启动失败!"
    fi
    
    echo
    echo -e "按任意键返回主菜单..."
    read -n 1
    show_main_menu
}

# 停止服务
stop_service() {
    clear_screen
    show_header
    echo -e "${BLUE}[操作]${NC} 正在停止 LayerEdge Light Node 服务..."
    
    sudo systemctl stop layeredge-light-node
    
    if ! systemctl is-active --quiet layeredge-light-node; then
        echo -e "${GREEN}[成功]${NC} LayerEdge Light Node 服务已成功停止!"
    else
        echo -e "${RED}[错误]${NC} LayerEdge Light Node 服务停止失败!"
    fi
    
    echo
    echo -e "按任意键返回主菜单..."
    read -n 1
    show_main_menu
}

# 重启服务
restart_service() {
    clear_screen
    show_header
    echo -e "${BLUE}[操作]${NC} 正在重启 LayerEdge Light Node 服务..."
    
    sudo systemctl restart layeredge-light-node
    
    if systemctl is-active --quiet layeredge-light-node; then
        echo -e "${GREEN}[成功]${NC} LayerEdge Light Node 服务已成功重启!"
    else
        echo -e "${RED}[错误]${NC} LayerEdge Light Node 服务重启失败!"
    fi
    
    echo
    echo -e "按任意键返回主菜单..."
    read -n 1
    show_main_menu
}

# 显示状态
show_status() {
    clear_screen
    show_header
    echo -e "${BLUE}[信息]${NC} LayerEdge Light Node 服务状态:"
    echo
    
    systemctl status layeredge-light-node
    
    echo
    echo -e "按任意键返回主菜单..."
    read -n 1
    show_main_menu
}

# 显示日志
show_logs() {
    clear_screen
    show_header
    echo -e "${BLUE}[信息]${NC} LayerEdge Light Node 服务日志:"
    echo -e "${YELLOW}提示: 按 Ctrl+C 退出日志查看${NC}"
    echo
    
    sudo journalctl -u layeredge-light-node -f
    
    show_main_menu
}

# 配置管理菜单
config_management() {
    clear_screen
    show_header
    
    echo -e "${YELLOW}配置管理:${NC}"
    echo -e "${GREEN}1)${NC} 编辑环境配置文件"
    echo -e "${GREEN}2)${NC} 查看当前配置"
    echo -e "${GREEN}0)${NC} 返回主菜单"
    echo
    echo -n -e "${YELLOW}请输入选项 [0-2]:${NC} "
    read -r choice
    
    case \$choice in
        1) edit_config ;;
        2) view_config ;;
        0) show_main_menu ;;
        *) 
            echo -e "${RED}无效选项!${NC}"
            sleep 2
            config_management
            ;;
    esac
}

# 编辑配置文件
edit_config() {
    clear_screen
    show_header
    echo -e "${BLUE}[操作]${NC} 编辑环境配置文件:"
    
    if [ -f "/root/light-node/.env" ]; then
        sudo nano /root/light-node/.env
    else
        echo -e "${RED}[错误]${NC} 找不到配置文件: /root/light-node/.env"
        sleep 2
    fi
    
    echo
    echo -e "${YELLOW}提示: 修改配置后，请重启服务以应用更改${NC}"
    echo -e "按任意键返回..."
    read -n 1
    config_management
}

# 查看当前配置
view_config() {
    clear_screen
    show_header
    echo -e "${BLUE}[信息]${NC} 当前环境配置:"
    echo
    
    if [ -f "/root/light-node/.env" ]; then
        cat /root/light-node/.env | grep -v "PRIVATE_KEY"
        echo "PRIVATE_KEY='********' (已隐藏)"
    else
        echo -e "${RED}[错误]${NC} 找不到配置文件: /root/light-node/.env"
    fi
    
    echo
    echo -e "按任意键返回..."
    read -n 1
    config_management
}

# 系统信息
system_info() {
    clear_screen
    show_header
    echo -e "${BLUE}[信息]${NC} 系统信息:"
    echo
    
    echo -e "${YELLOW}操作系统:${NC}"
    cat /etc/os-release | grep "PRETTY_NAME" | cut -d '\"' -f 2
    
    echo -e "\n${YELLOW}内核版本:${NC}"
    uname -r
    
    echo -e "\n${YELLOW}CPU信息:${NC}"
    lscpu | grep "Model name" | cut -d ':' -f 2 | sed 's/^[ \\t]*//' || echo "无法获取CPU信息"
    
    echo -e "\n${YELLOW}内存使用情况:${NC}"
    free -h
    
    echo -e "\n${YELLOW}磁盘使用情况:${NC}"
    df -h /
    
    echo -e "\n${YELLOW}Go版本:${NC}"
    go version 2>/dev/null || echo "Go未安装"
    
    echo -e "\n${YELLOW}Rust版本:${NC}"
    rustc --version 2>/dev/null || echo "Rust未安装"
    
    echo -e "\n${YELLOW}LayerEdge服务状态:${NC}"
    systemctl is-active layeredge-light-node
    
    echo
    echo -e "按任意键返回主菜单..."
    read -n 1
    show_main_menu
}

# 卸载服务
uninstall_service() {
    clear_screen
    show_header
    echo -e "${YELLOW}[警告]${NC} 您确定要卸载 LayerEdge Light Node 服务吗? (y/n)"
    read -r confirm
    
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo -e "${GREEN}[信息]${NC} 已取消卸载操作"
        sleep 2
        show_main_menu
        return
    fi
    
    echo -e "${BLUE}[操作]${NC} 正在卸载 LayerEdge Light Node 服务..."
    
    # 停止并禁用服务
    systemctl stop layeredge-light-node 2>/dev/null
    systemctl disable layeredge-light-node 2>/dev/null
    
    # 删除服务文件
    rm -f /etc/systemd/system/layeredge-light-node.service
    systemctl daemon-reload
    
    # 删除安装目录
    if [ -d "$HOME/light-node" ]; then
        rm -rf "$HOME/light-node"
        echo -e "${GREEN}[信息]${NC} 已删除 light-node 目录"
    fi
    
    echo -e "${GREEN}[成功]${NC} LayerEdge Light Node 服务已成功卸载!"
    echo
    echo -e "按任意键返回主菜单..."
    read -n 1
    show_main_menu
}

# 启动主菜单
show_main_menu
EOL
    
    # 返回主菜单
    show_main_menu
}

# 显示使用说明
show_instructions() {
    log_step "安装完成"
    
    echo -e "\n${GREEN}LayerEdge CLI Light Node 已成功安装!${NC}\n"
    
    echo -e "${YELLOW}管理命令:${NC}"
    echo -e "  交互式管理菜单: ${GREEN}sudo bash $0 menu${NC}"
    
    echo -e "\n${YELLOW}重要提示:${NC}"
    echo -e "  1. 请确保已正确配置 ${GREEN}light-node/.env${NC} 文件中的环境变量"
    echo -e "  2. 如需修改配置，请通过管理菜单中的'配置管理'选项进行修改"
    echo -e "  3. 所有节点管理操作（启动/停止/重启/查看状态/查看日志）均可通过交互式菜单完成"
    
    echo -e "\n${GREEN}感谢使用LayerEdge!${NC}\n"
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
    
    # 检查是否有参数
    if [ "$1" == "menu" ]; then
        # 直接运行菜单
        run_management_menu
        exit 0
    fi
    
    # 执行安装步骤
    install_dependencies
    clone_repository
    start_merkle_service
    configure_environment
    build_and_run_light_node
    show_instructions
    
    # 询问是否立即运行管理菜单
    echo -e "\n${YELLOW}是否立即运行管理菜单? (y/n)${NC}"
    read -r run_menu
    if [[ $run_menu == "y" || $run_menu == "Y" ]]; then
        run_management_menu
    else
        echo -e "\n${GREEN}您可以随时通过运行以下命令启动管理菜单:${NC}"
        echo -e "${BLUE}sudo bash $0 menu${NC}\n"
    fi
}

# 执行主函数
main