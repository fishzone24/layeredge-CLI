# LayerEdge CLI Light Node

一键部署LayerEdge CLI轻节点到Ubuntu系统

## 功能特性
- 自动安装Go/Rust等编译依赖
- 配置Risc0零知识证明环境
- 部署Merkle验证服务
- 提供节点管理脚本(启动/停止/状态查看)
- 集成LayerEdge Dashboard连接

## 系统要求
- Ubuntu 20.04/22.04 LTS
- 4核CPU / 8GB内存 / 50GB存储

## 快速安装
```bash
# 单条命令安装
curl -sL https://raw.githubusercontent.com/fishzone24/layeredge-CLI/refs/heads/master/install_layeredge.sh | sudo bash

# 备选分步安装（如需）：
# wget https://raw.githubusercontent.com/fishzone24/layeredge-CLI/refs/heads/master/install_layeredge.sh
# chmod +x install_layeredge.sh
# sudo ./install_layeredge.sh
```

## 使用说明
安装完成后：
1. 编辑.env文件配置私钥
```bash
nano .env
```
2. 使用交互式管理菜单（安装脚本会自动创建）：
```bash
bash ~/layeredge_menu.sh
```
通过菜单可以：
- 启动/停止/重启服务
- 查看服务状态和日志
- 管理配置文件
- 查看系统信息
- 卸载服务

## 安全提示
⚠️ 请妥善保管PRIVATE_KEY配置
⚠️ 建议在防火墙开放3001端口(TCP)

## 技术支持
访问[LayerEdge Dashboard](https://dashboard.layeredge.io) 查看节点状态