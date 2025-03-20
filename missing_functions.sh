# 构建并运行Light Node
build_and_run_light_node() {
    log_step "构建并运行Light Node"
    
    # 确保在light-node目录中
    if [ ! -d "light-node" ]; then
        cd ..
        if [ ! -d "light-node" ]; then
            log_error "找不到light-node目录，请确保仓库克隆正确"
            exit 1
        fi
    fi
    
    cd light-node
    
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

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本"
    
    # 确保在主目录中
    cd $HOME
    
    # 创建启动脚本
    cat > start_layeredge.sh << EOL
#!/bin/bash
systemctl start layeredge-light-node
echo "LayerEdge Light Node服务已启动"
EOL
    
    # 创建停止脚本
    cat > stop_layeredge.sh << EOL
#!/bin/bash
systemctl stop layeredge-light-node
echo "LayerEdge Light Node服务已停止"
EOL
    
    # 创建重启脚本
    cat > restart_layeredge.sh << EOL
#!/bin/bash
systemctl restart layeredge-light-node
echo "LayerEdge Light Node服务已重启"
EOL
    
    # 创建状态检查脚本
    cat > status_layeredge.sh << EOL
#!/bin/bash
systemctl status layeredge-light-node
EOL
    
    # 创建日志查看脚本
    cat > logs_layeredge.sh << EOL
#!/bin/bash
journalctl -u layeredge-light-node -f
EOL
    
    # 添加执行权限
    chmod +x start_layeredge.sh stop_layeredge.sh restart_layeredge.sh status_layeredge.sh logs_layeredge.sh
    
    log_info "管理脚本已创建在主目录中"
}

# 显示使用说明
show_instructions() {
    log_step "安装完成"
    
    echo -e "\n${GREEN}LayerEdge CLI Light Node 已成功安装!${NC}\n"
    
    echo -e "${YELLOW}管理命令:${NC}"
    echo -e "  启动服务: ${GREEN}bash ~/start_layeredge.sh${NC}"
    echo -e "  停止服务: ${GREEN}bash ~/stop_layeredge.sh${NC}"
    echo -e "  重启服务: ${GREEN}bash ~/restart_layeredge.sh${NC}"
    echo -e "  查看状态: ${GREEN}bash ~/status_layeredge.sh${NC}"
    echo -e "  查看日志: ${GREEN}bash ~/logs_layeredge.sh${NC}"
    
    echo -e "\n${YELLOW}重要提示:${NC}"
    echo -e "  1. 请确保已正确配置 ${GREEN}light-node/.env${NC} 文件中的环境变量"
    echo -e "  2. 如需修改配置，请编辑 ${GREEN}light-node/.env${NC} 文件后重启服务"
    echo -e "  3. 服务日志可通过 ${GREEN}journalctl -u layeredge-light-node -f${NC} 查看"
    
    echo -e "\n${GREEN}感谢使用LayerEdge!${NC}\n"
}