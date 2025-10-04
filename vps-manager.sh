k```

您会立刻看到熟悉的彩色管理菜单，并且所有输入选项都会正常等待您的操作。

---

### 这是为您准备的最终代码

您无需关心代码细节，只需运行上面的安装命令即可。代码放在这里供您审阅。

#### 1. 终极安装器 (`final-installer.sh`)
这是您通过 `curl` 运行的脚本。它的任务就是正确地把主程序安装好。

```bash
#!/bin/bash
# k-script 终极安装器
# 采用行业标准方式，将脚本安装到 /usr/local/bin

# --- 变量定义 ---
RED="\033[1;31m"; GREEN="\033[1;32m"; YELLOW="\033[1;33m"; CYAN="\033[1;36m"; RESET="\033[0m"
INSTALL_PATH="/usr/local/bin/k"
SCRIPT_URL="https://raw.githubusercontent.com/chengege666/vps-manager/main/k-main.sh"

# --- 权限检查 ---
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 错误：请使用 root 权限运行此安装脚本${RESET}"
    exit 1
fi

echo -e "${CYAN}--- 开始安装 VPS & BBR 综合管理工具 ---${RESET}"

# 1. 下载主脚本到目标路径
echo "正在下载主脚本到 $INSTALL_PATH ..."
if curl -sLf "$SCRIPT_URL" -o "$INSTALL_PATH"; then
    echo -e "${GREEN}✓ 主脚本下载成功！${RESET}"
else
    echo -e "${RED}✗ 主脚本下载失败，请检查网络或 URL 是否正确。${RESET}"
    exit 1
fi

# 2. 赋予执行权限
chmod +x "$INSTALL_PATH"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 脚本已设置为可执行。${RESET}"
else
    echo -e "${RED}✗ 设置执行权限失败。${RESET}"
    exit 1
fi

# 3. 最终成功提示
echo ""
echo -e "${GREEN}★★★ 安装完成！ ★★★${RESET}"
echo -e "${YELLOW}您现在可以随时随地通过输入以下命令来启动工具:${RESET}"
echo ""
echo -e "  ${CYAN}k${RESET}"
echo ""
