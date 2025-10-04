#!/bin/bash
# ==========================================
# VPS & BBR 综合管理工具 (自安装/带卸载)
# 特点: 一键安装，k命令启动，自带卸载功能
# 作者: 陈哥哥
# ==========================================

# --- 全局变量和颜色定义 ---
RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; MAGENTA="\033[1;35m"; CYAN="\033[1;36m"; RESET="\033[0m"
RESULT_FILE="$HOME/bbr_result.txt"
INSTALL_PATH="/usr/local/bin/k"

# -------------------------------
# 欢迎标题
# -------------------------------
print_header() {
    clear
    echo -e "${CYAN}======================================================${RESET}"
    echo -e "${MAGENTA}              VPS & BBR 综合管理工具                ${RESET}"
    echo -e "${CYAN}------------------------------------------------------${RESET}"
    echo -e "${YELLOW}       系统 | Docker | BBR | 输入 'k' 随时启动      ${RESET}"
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

# ======================================================
#  功能模块 (VPS + BBR)
# ======================================================

sys_info() {
    echo "-------- 系统信息 --------"
    echo "操作系统: $(lsb_release -d 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
    echo "内核版本: $(uname -r)"
    free -h
    df -h
    echo "---------------------------"
}

sys_update() {
    echo "-------- 系统更新 --------"
    if command -v apt-get >/dev/null 2>&1; then apt-get update && apt-get upgrade -y
    elif command -v yum >/dev/null 2>&1; then yum update -y
    else echo "未知包管理器"; fi
    echo "---------------------------"
}

sys_clean() {
    echo "-------- 系统清理 --------"
    if command -v apt-get >/dev/null 2>&1; then apt-get autoremove -y; apt-get clean
    elif command -v yum >/dev/null 2>&1; then yum autoremove -y; yum clean all; fi
    if command -v docker >/dev/null 2>&1; then echo "清理Docker..."; docker system prune -af; fi
    echo "---------------------------"
}

docker_manage() {
    if ! command -v docker >/dev/null 2>&1; then
        read -rp "未安装 Docker, 是否立即安装? (y/n): " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun; fi
    fi
    if command -v docker >/dev/null 2>&1; then echo "-------- Docker 容器列表 --------"; docker ps -a; else echo "Docker 未安装。"; fi
}

run_bbr_test_suite() {
    if ! command -v speedtest-cli >/dev/null 2>&1; then 
        echo "正在安装 speedtest-cli..."
        if command -v apt-get >/dev/null 2>&1; then apt-get install speedtest-cli -y; else yum install speedtest-cli -y; fi
    fi
    > "$RESULT_FILE"
    for MODE in "bbr" "bbrplus" "bbrv2" "bbrv3"; do
        echo -e "\n${CYAN}>>> 正在测试 $MODE ...${RESET}"
        sysctl -w net.ipv4.tcp_congestion_control=$MODE >/dev/null 2>&1
        if [ "$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')" != "$MODE" ]; then
            echo -e "${YELLOW}切换到 $MODE 失败, 可能未安装此内核。${RESET}"; continue;
        fi
        RAW=$(speedtest-cli --simple 2>/dev/null)
        if [ -z "$RAW" ]; then echo -e "${RED}测速失败${RESET}" | tee -a "$RESULT_FILE"; else
            echo "$RAW" | awk -v mode="$MODE" '/Ping/{p=$2} /Download/{d=$2} /Upload/{u=$2} END{printf "%-10s | Ping: %-7s ms | Down: %-7s Mbps | Up: %-7s Mbps\n", mode, p, d, u}' | tee -a "$RESULT_FILE"
        fi
    done
    echo -e "\n=== 测试完成，结果汇总 ==="; cat "$RESULT_FILE"
}

run_bbr_switch() {
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

# ======================================================
#  卸载脚本功能 (新功能)
# ======================================================
uninstall_script() {
    clear
    echo -e "${RED}警告：此操作将从系统中永久删除 'k' 命令。${RESET}"
    read -rp "您确定要卸载此脚本吗? (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if rm -f "$INSTALL_PATH"; then
            echo -e "${GREEN}✓ 脚本已成功卸载。${RESET}"
            echo "感谢使用，再见！"
            exit 0
        else
            echo -e "${RED}卸载失败。请检查权限。${RESET}"
            pause
        fi
    else
        echo "已取消卸载。"
        sleep 2
    fi
}


# -------------------------------
# 主程序入口
# -------------------------------

# --- 检查是否为 root 用户 ---
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 错误：请使用 root 权限运行本脚本${RESET}"
    exit 1
fi

# --- 主菜单循环 ---
while true; do
    print_header
    echo "--- 系统与服务管理 ---"
    echo -e " ${GREEN}1)${RESET} 查看系统信息    ${GREEN}2)${RESET} 系统更新    ${GREEN}3)${RESET} 系统清理    ${GREEN}4)${RESET} Docker 管理"
    echo ""
    echo "--- BBR 加速管理 ---"
    echo -e " ${GREEN}5)${RESET} 执行 BBR 测速对比"
    echo -e " ${GREEN}6)${RESET} 安装/切换 BBR 内核"
    echo ""
    echo "--- 脚本管理 ---"
    echo -e " ${GREEN}8)${RESET} 卸载此脚本"
    echo -e " ${GREEN}9)${RESET} 退出脚本"
    echo ""
    read -p "输入数字选择: " choice
    
    case "$choice" in
        1) clear; sys_info; pause ;;
        2) clear; sys_update; pause ;;
        3) clear; sys_clean; pause ;;
        4) clear; docker_manage; pause ;;
        5) clear; run_bbr_test_suite; pause ;;
        6) clear; run_bbr_switch; pause ;;
        8) uninstall_script ;;
        9) echo "退出脚本"; exit 0 ;;
        *) echo -e "${RED}无效选项，请输入有效数字${RESET}"; sleep 2 ;;
    esac
done
