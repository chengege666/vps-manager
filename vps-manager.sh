#!/bin/bash
# ==========================================
# VPS & BBR 综合管理工具
# 结合了 VPS 管理功能和 BBR 测速的交互界面
# GitHub: https://github.com/chengege666
# ==========================================

# --- 全局变量和颜色定义 ---
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"
RESULT_FILE="bbr_result.txt"

# -------------------------------
# 欢迎标题
# -------------------------------
print_header() {
    clear
    echo -e "${CYAN}======================================================${RESET}"
    echo -e "${MAGENTA}              VPS & BBR 综合管理工具                ${RESET}"
    echo -e "${CYAN}------------------------------------------------------${RESET}"
    echo -e "${YELLOW}  一个脚本，管理系统、Docker、SSH 和 BBR 加速！  ${RESET}"
    echo -e "${CYAN}======================================================${RESET}"
    echo ""
}

# -------------------------------
# root 权限及核心依赖检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

check_initial_deps() {
    for CMD in curl wget git; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo "缺少核心依赖: $CMD，正在尝试安装..."
            if [ -f /etc/debian_version ]; then apt update >/dev/null && apt install -y $CMD
            elif [ -f /etc/redhat-release ]; then yum install -y $CMD 2>/dev/null || dnf install -y $CMD
            else echo -e "${RED}无法自动安装依赖，请手动安装 $CMD 后重试。${RESET}"; exit 1; fi
        fi
    done
}


# ======================================================
#  VPS 管理功能模块
# ======================================================

sys_info() {
    echo "-------- 系统信息 --------"
    echo "操作系统: $(lsb_release -d 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
    echo "内核版本: $(uname -r)"
    echo "CPU 信息: $(lscpu | grep 'Model name')"
    echo "内存信息: $(free -h | awk '/Mem:/ {print $2 " 总, " $3 " 已用, " $4 " 空闲"}')"
    echo "磁盘空间: $(df -h --total | grep 'total')"
    echo "系统负载: $(uptime | awk -F'load average:' '{print $2}')"
    echo "---------------------------"
}

sys_update() {
    echo "-------- 系统更新 --------"
    if command -v apt >/dev/null 2>&1; then apt update && apt upgrade -y
    elif command -v yum >/dev/null 2>&1; then yum update -y
    else echo "未知系统包管理器，无法更新！"; fi
    echo "---------------------------"
}

sys_clean() {
    echo "-------- 系统清理 --------"
    if command -v apt >/dev/null 2>&1; then apt autoremove -y; apt clean
    elif command -v yum >/dev/null 2>&1; then yum autoremove -y; yum clean all; fi
    if command -v docker >/dev/null 2>&1; then docker system prune -af; fi
    echo "---------------------------"
}

port_manage() {
    echo "-------- 端口管理 --------"
    echo "当前开放端口:"; ss -tuln; echo "---------------------------"
    echo "1) 添加防火墙端口"; echo "2) 删除防火墙端口"; echo "3) 返回"
    read -rp "请选择操作: " port_choice
    case "$port_choice" in
        1) read -rp "请输入端口号: " add_port; if command -v ufw >/dev/null 2>&1; then ufw allow "$add_port"; echo "端口 $add_port 已允许"; else echo "未找到 UFW"; fi ;;
        2) read -rp "请输入端口号: " del_port; if command -v ufw >/dev/null 2>&1; then ufw delete allow "$del_port"; echo "端口 $del_port 已删除"; else echo "未找到 UFW"; fi ;;
        3) return ;;
        *) echo "无效选项" ;;
    esac
}

docker_manage() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "检测到 Docker 未安装。"
        read -rp "是否使用官方一键脚本安装 Docker? (y/n): " install_choice
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            if ! command -v docker >/dev/null 2>&1; then echo -e "${RED}Docker 安装失败。${RESET}"; return; fi
            echo -e "${GREEN}Docker 安装成功！${RESET}"
        else
            return
        fi
    fi
    clear; echo "-------- Docker 管理 --------"; docker ps -a; echo "---------------------------"
    # 此处可以添加更详细的 Docker 管理子菜单
}

ssh_manage() {
    echo "-------- SSH 管理 --------"
    echo "1) 修改 SSH 端口"; echo "2) 返回"
    read -rp "请选择操作: " ssh_choice
    case "$ssh_choice" in
        1)
            read -rp "请输入新 SSH 端口 (1024-65535): " new_port
            if [[ "$new_port" -ge 1024 && "$new_port" -le 65535 ]]; then
                sed -i.bak "s/^#*Port [0-9]*/Port $new_port/" /etc/ssh/sshd_config
                systemctl restart sshd
                echo -e "${GREEN}SSH 端口已修改为 $new_port，请记得在防火墙放行！${RESET}"
            else
                echo -e "${RED}端口号不合法${RESET}"
            fi
            ;;
        2) return ;;
        *) echo "无效选项" ;;
    esac
}

# ======================================================
#  BBR 加速功能模块 (子菜单)
# ======================================================

bbr_deps_check() {
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo "未检测到 speedtest-cli，正在安装..."
        if [ -f /etc/debian_version ]; then apt install -y speedtest-cli
        elif [ -f /etc/redhat-release ]; then yum install -y speedtest-cli 2>/dev/null || dnf install -y speedtest-cli
        else echo -e "${RED}无法自动安装 speedtest-cli。${RESET}"; return 1; fi
    fi
}

run_bbr_test() {
    MODE=$1
    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}"
    case $MODE in
        "BBR") sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 ;;
        "BBR Plus") sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null 2>&1 ;;
        "BBRv2") sysctl -w net.ipv4.tcp_congestion_control=bbrv2 >/dev/null 2>&1 ;;
        "BBRv3") sysctl -w net.ipv4.tcp_congestion_control=bbrv3 >/dev/null 2>&1 ;;
    esac
    if [ $? -ne 0 ]; then echo -e "${YELLOW}切换到 $MODE 失败，可能未安装该内核。${RESET}"; return; fi
    RAW=$(speedtest-cli --simple 2>/dev/null)
    if [ -z "$RAW" ]; then RAW=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python - --simple 2>/dev/null); fi
    if [ -z "$RAW" ]; then echo -e "${RED}$MODE 测速失败${RESET}" | tee -a "$RESULT_FILE"; return; fi
    PING=$(echo "$RAW" | grep "Ping" | awk '{print $2}'); DOWNLOAD=$(echo "$RAW" | grep "Download" | awk '{print $2}'); UPLOAD=$(echo "$RAW" | grep "Upload" | awk '{print $2}')
    echo "$MODE | Ping: ${PING}ms | Down: ${DOWNLOAD} Mbps | Up: ${UPLOAD} Mbps" | tee -a "$RESULT_FILE"; echo ""
}

run_bbr_switch() {
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

bbr_submenu() {
    bbr_deps_check || return
    while true; do
        clear
        echo -e "${CYAN}==================================================${RESET}"
        echo -e "${MAGENTA}                 BBR 加速管理                 ${RESET}"
        echo -e "${CYAN}--------------------------------------------------${RESET}"
        echo "1) 执行 BBR 测速对比"
        echo "2) 安装/切换 BBR 内核（运行外部脚本）"
        echo "3) 返回主菜单"
        read -p "输入数字选择: " bbr_choice
        case "$bbr_choice" in
            1)
                > "$RESULT_FILE"
                for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do run_bbr_test "$MODE"; done
                echo "=== 测试完成，结果汇总 ==="; cat "$RESULT_FILE"; echo ""
                read -n1 -p "按任意键返回..."
                ;;
            2)
                run_bbr_switch
                read -n1 -p "按任意键返回..."
                ;;
            3)
                return
                ;;
            *)
                echo "无效选项，请输入 1-3"; sleep 2
                ;;
        esac
    done
}


# -------------------------------
# 主菜单
# -------------------------------
show_menu() {
    while true; do
        print_header
        echo "请选择操作："
        echo -e " ${GREEN}1)${RESET} 查看系统信息    ${GREEN}5)${RESET} Docker 管理"
        echo -e " ${GREEN}2)${RESET} 系统更新        ${GREEN}6)${RESET} SSH 管理"
        echo -e " ${GREEN}3)${RESET} 系统清理        ${GREEN}7)${RESET} BBR 加速管理"
        echo -e " ${GREEN}4)${RESET} 端口管理        ${GREEN}8)${RESET} 退出"
        echo ""
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1) clear; sys_info ;;
            2) clear; sys_update ;;
            3) clear; sys_clean ;;
            4) clear; port_manage ;;
            5) clear; docker_manage ;;
            6) clear; ssh_manage ;;
            7) bbr_submenu ;;
            8) echo "退出脚本"; exit 0 ;;
            *) echo "无效选项，请输入 1-8"; sleep 2 ;;
        esac
        
        # 在 BBR 子菜单返回后，主菜单不会暂停，其他选项会暂停
        if [[ "$choice" -ne 7 && "$choice" -ne 8 ]]; then
            echo ""
            read -n1 -p "按任意键返回主菜单..."
        fi
    done
}

# -------------------------------
# 主程序入口
# -------------------------------
check_root
check_initial_deps
show_menu
