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
# 暂停函数
# -------------------------------
pause() {
    echo ""
    read -n1 -p "按任意键返回主菜单..."
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
            elif [ -f /etc/redhat_release ]; then yum install -y $CMD 2>/dev/null || dnf install -y $CMD
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
    if command -v docker >/dev/null 2>&1; then echo "清理Docker..."; docker system prune -af; fi
    echo "---------------------------"
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
    clear; echo "-------- Docker 容器列表 --------"; docker ps -a; echo "---------------------------"
    # 这里可以根据需要添加更详细的Docker管理菜单
}


# ======================================================
#  BBR 加速功能模块
# ======================================================

bbr_deps_check() {
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo "未检测到 speedtest-cli，正在安装..."
        if [ -f /etc/debian_version ]; then apt install -y speedtest-cli
        elif [ -f /etc/redhat_release ]; then yum install -y speedtest-cli 2>/dev/null || dnf install -y speedtest-cli
        else echo -e "${RED}无法自动安装 speedtest-cli。${RESET}"; return 1; fi
    fi
    return 0
}

run_bbr_test_suite() {
    bbr_deps_check || return # 检查依赖，如果失败则返回
    
    > "$RESULT_FILE" # 清空结果文件
    echo ""
    for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
        echo -e "${CYAN}>>> 正在尝试切换到 $MODE 并测速...${RESET}"
        # 尝试切换内核
        sysctl -w net.ipv4.tcp_congestion_control=$MODE >/dev/null 2>&1
        # 检查是否切换成功
        CURRENT_BBR=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
        if [ "$CURRENT_BBR" != "$MODE" ]; then
            echo -e "${YELLOW}切换到 $MODE 失败，可能未安装该内核或模块。${RESET}\n"
            continue # 跳过此模式
        fi
        
        # 执行测速
        RAW=$(speedtest-cli --simple 2>/dev/null)
        if [ -z "$RAW" ]; then
            echo -e "${YELLOW}⚠️ speedtest-cli 失败，尝试备用方法...${RESET}"
            RAW=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python - --simple 2>/dev/null)
        fi
        if [ -z "$RAW" ]; then
            echo -e "${RED}$MODE 测速失败${RESET}" | tee -a "$RESULT_FILE"
        else
            PING=$(echo "$RAW" | grep "Ping" | awk '{print $2}')
            DOWNLOAD=$(echo "$RAW" | grep "Download" | awk '{print $2}')
            UPLOAD=$(echo "$RAW" | grep "Upload" | awk '{print $2}')
            echo "$MODE | Ping: ${PING}ms | Down: ${DOWNLOAD} Mbps | Up: ${UPLOAD} Mbps" | tee -a "$RESULT_FILE"
        fi
        echo ""
    done
    
    echo "=== 测试完成，结果汇总 (已保存到 $RESULT_FILE) ==="
    cat "$RESULT_FILE"
}

run_bbr_switch() {
    echo "正在下载并运行 BBR 内核切换脚本..."
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

# -------------------------------
# 主菜单
# -------------------------------
show_menu() {
    while true; do
        print_header
        echo "--- 系统与服务管理 ---"
        echo -e " ${GREEN}1)${RESET} 查看系统信息    ${GREEN}2)${RESET} 系统更新    ${GREEN}3)${RESET} 系统清理    ${GREEN}4)${RESET} Docker 管理"
        echo ""
        echo "--- BBR 加速管理 ---"
        echo -e " ${GREEN}5)${RESET} 执行 BBR 测速对比"
        echo -e " ${GREEN}6)${RESET} 安装/切换 BBR 内核"
        echo ""
        echo "--- 其他 ---"
        echo -e " ${GREEN}7)${RESET} 退出脚本"
        echo ""
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1) clear; sys_info; pause ;;
            2) clear; sys_update; pause ;;
            3) clear; sys_clean; pause ;;
            4) clear; docker_manage; pause ;;
            5) clear; run_bbr_test_suite; pause ;;
            6) clear; run_bbr_switch; pause ;;
            7) echo "退出脚本"; exit 0 ;;
            *) echo -e "${RED}无效选项，请输入 1-7${RESET}"; sleep 2 ;;
        esac
    done
}

# -------------------------------
# 主程序入口
# -------------------------------
check_root
check_initial_deps
show_menu
