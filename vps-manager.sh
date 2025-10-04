#!/bin/bash
# ==========================================
# VPS 管理工具 (交互式)
# 功能: 系统信息、系统更新、系统清理、端口管理、Docker管理、SSH管理
# 作者: 陈哥哥 
# ==========================================

# 检查是否 root
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 用户运行此脚本！"
  exit 1
fi

# ==============================
# 暂停并等待用户按键的函数
# ==============================
pause() {
    read -rp "按 Enter 键返回主菜单..."
}


# ==============================
# 系统信息函数
# ==============================
sys_info() {
    echo "-------- 系统信息 --------"
    echo "操作系统: $(lsb_release -d 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
    echo "内核版本: $(uname -r)"
    echo "CPU 信息: $(lscpu | grep 'Model name')"
    echo "内存信息: $(free -h | awk '/Mem:/ {print $2 " 总, " $3 " 已用, " $4 " 空闲"}')"
    echo "磁盘空间: $(df -h --total | grep 'total')"
    echo "系统负载: $(uptime | awk -F'load average:' '{print $2}')"
    echo "当前登录用户: $(who)"
    echo "---------------------------"
}

# ==============================
# 系统更新函数
# ==============================
sys_update() {
    echo "-------- 系统更新 --------"
    if command -v apt >/dev/null 2>&1; then
        apt update && apt upgrade -y
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
    else
        echo "未知系统包管理器，无法更新！"
    fi
    echo "---------------------------"
}

# ==============================
# 系统清理函数
# ==============================
sys_clean() {
    echo "-------- 系统清理 --------"
    if command -v apt >/dev/null 2>&1; then
        apt autoremove -y
        apt clean
    elif command -v yum >/dev/null 2>&1; then
        yum autoremove -y
        yum clean all
    fi
    # 清理 Docker
    if command -v docker >/dev/null 2>&1; then
        docker system prune -af
    fi
    echo "---------------------------"
}

# ==============================
# 端口管理函数
# ==============================
port_manage() {
    echo "-------- 端口管理 --------"
    echo "当前开放端口:"
    ss -tuln
    echo "---------------------------"
    echo "1) 添加防火墙端口"
    echo "2) 删除防火墙端口"
    echo "3) 检查端口占用"
    echo "4) 返回上级菜单"
    read -rp "请选择操作: " port_choice
    case "$port_choice" in
        1)
            read -rp "请输入端口号: " add_port
            if command -v ufw >/dev/null 2>&1; then
                ufw allow "$add_port"
                echo "端口 $add_port 已允许"
            else
                echo "请手动添加防火墙规则"
            fi
            ;;
        2)
            read -rp "请输入端口号: " del_port
            if command -v ufw >/dev/null 2>&1; then
                ufw delete allow "$del_port"
                echo "端口 $del_port 已删除"
            else
                echo "请手动删除防火墙规则"
            fi
            ;;
        3)
            read -rp "请输入端口号: " check_port
            lsof -i :"$check_port"
            ;;
        4) return ;;
        *) echo "无效选项" ;;
    esac
    echo "---------------------------"
}

# ==============================
# Docker 管理函数 (已优化)
# ==============================
docker_manage() {
    # 检查 Docker 是否安装
    if ! command -v docker >/dev/null 2>&1; then
        echo "检测到 Docker 未安装。"
        read -rp "是否使用官方一键脚本安装 Docker? (y/n): " install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            echo "正在执行 Docker 官方一键安装脚本..."
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL https://get.docker.com -o get-docker.sh
            elif command -v wget >/dev/null 2>&1; then
                wget -O get-docker.sh https://get.docker.com
            else
                echo "错误: 未找到 curl 或 wget，无法下载安装脚本。"
                return
            fi
            
            if [ ! -f "get-docker.sh" ]; then
                echo "错误: Docker 安装脚本下载失败。"
                return
            fi

            sudo sh get-docker.sh --mirror Aliyun
            rm get-docker.sh

            if command -v docker >/dev/null 2>&1; then
                echo "Docker 安装成功！"
                # 安装成功后，直接重新进入管理菜单
                docker_manage
                return
            else
                echo "Docker 安装失败，请检查网络或脚本输出。"
                return
            fi
        else
            echo "已取消 Docker 安装。"
            return
        fi
    fi

    echo "-------- Docker 管理 --------"
    echo "1) 查看容器"
    echo "2) 启动容器"
    echo "3) 停止容器"
    echo "4) 重启容器"
    echo "5) 查看镜像"
    echo "6) 拉取镜像"
    echo "7) 运行新容器"
    echo "8) 清理无用资源"
    echo "9) 返回上级菜单"
    read -rp "请选择操作: " docker_choice

    case "$docker_choice" in
        1) docker ps -a ;;
        2) read -rp "容器名称或ID: " c_name; docker start "$c_name" ;;
        3) read -rp "容器名称或ID: " c_name; docker stop "$c_name" ;;
        4) read -rp "容器名称或ID: " c_name; docker restart "$c_name" ;;
        5) docker images ;;
        6) read -rp "镜像名称: " img_name; docker pull "$img_name" ;;
        7)
            read -rp "镜像名称: " img_name
            read -rp "容器名称: " c_name
            read -rp "端口映射(格式: 80:80): " port_map
            docker run -d --name "$c_name" -p "$port_map" "$img_name"
            ;;
        8) docker system prune -af ;;
        9) return ;;
        *) echo "无效选项" ;;
    esac
    echo "---------------------------"
}


# ==============================
# SSH 管理函数（自动放行防火墙端口）
# ==============================
ssh_manage() {
    echo "-------- SSH 管理 --------"
    echo "1) 修改 SSH 端口"
    echo "2) 修改用户密码"
    echo "3) 返回上级菜单"
    read -rp "请选择操作: " ssh_choice

    case "$ssh_choice" in
        1)
            read -rp "请输入新 SSH 端口 (1024-65535): " new_port
            if [[ "$new_port" -ge 1024 && "$new_port" -le 65535 ]]; then
                cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
                sed -i "s/^#Port 22/Port $new_port/" /etc/ssh/sshd_config
                sed -i "s/^Port .*/Port $new_port/" /etc/ssh/sshd_config

                if command -v ufw >/dev/null 2>&1; then
                    ufw allow "$new_port"
                    echo "UFW: 已允许端口 $new_port"
                elif command -v iptables >/dev/null 2>&1; then
                    iptables -I INPUT -p tcp --dport "$new_port" -j ACCEPT
                    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
                    echo "iptables: 已允许端口 $new_port"
                else
                    echo "未检测到防火墙管理工具，请手动放行端口"
                fi

                systemctl restart sshd
                echo "SSH 端口已修改为 $new_port"
            else
                echo "端口号不合法"
            fi
            ;;
        2)
            read -rp "请输入用户名: " user_name
            if id "$user_name" >/dev/null 2>&1; then
                passwd "$user_name"
            else
                echo "用户不存在"
            fi
            ;;
        3) return ;;
        *) echo "无效选项" ;;
    esac
    echo "---------------------------"
}

# ==============================
# 主菜单 (最终优化版)
# ==============================
while true; do
    clear # 核心优化点1：每次循环前清屏
    echo ""
    echo "======== VPS 管理工具 ========"
    echo "1) 查看系统信息"
    echo "2) 系统更新"
    echo "3) 系统清理"
    echo "4) 端口管理"
    echo "5) Docker 管理"
    echo "6) SSH 管理"
    echo "7) 退出"
    read -rp "请选择操作: " choice

    case "$choice" in
        1) sys_info; pause ;;
        2) sys_update; pause ;;
        3) sys_clean; pause ;;
        4) port_manage; pause ;;
        5) docker_manage; pause ;;
        6) ssh_manage; pause ;;
        7) exit 0 ;;
        *) 
           echo "无效选项，请重新输入。"
           sleep 2 # 核心优化点2：错误提示后暂停2秒
           ;;
    esac
done
