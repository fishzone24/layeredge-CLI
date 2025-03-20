#!/bin/bash

# LayerEdge CLI 交互式菜单
# 此脚本提供LayerEdge CLI Light Node的交互式管理界面

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo -e "${GREEN}0)${NC} 退出"
    echo
    echo -n -e "${YELLOW}请输入选项 [0-7]:${NC} "
    read -r choice
    
    case $choice in
        1) start_service ;;
        2) stop_service ;;
        3) restart_service ;;
        4) show_status ;;
        5) show_logs ;;
        6) config_management ;;
        7) system_info ;;
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
    
    case $choice in
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
    cat /etc/os-release | grep "PRETTY_NAME" | cut -d '"' -f 2
    
    echo -e "\n${YELLOW}内核版本:${NC}"
    uname -r
    
    echo -e "\n${YELLOW}CPU信息:${NC}"
    lscpu | grep "Model name" | cut -d ':' -f 2 | sed 's/^[ \t]*//' || echo "无法获取CPU信息"
    
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

# 启动主菜单
show_main_menu