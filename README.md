bash <(curl -s https://raw.githubusercontent.com/<chengege666/vps-manager/main/vps-manager.sh)
VPS 工具箱 (bbr-gj)

[图片] https://img.shields.io/badge/Shell_Script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white

一个功能强大的 VPS 管理工具集，专注于 BBR 算法测试与系统优化，提供一键式 BBR 测速对比、内核切换、系统管理和 Docker 容器管理等功能。

功能亮点

1. BBR 综合测速
   - 自动测试并对比 BBR、BBR Plus、BBRv2、BBRv3 四种算法的网络性能
   - 实时显示 Ping 延迟、下载和上传速度
   - 结果自动保存到 
"bbr_result.txt"
2. BBR 内核管理
   - 一键安装/切换 BBR 内核（集成 ylx2016/Linux-NetSpeed 脚本）
3. 系统管理工具
   - 实时查看系统信息（OS/CPU/内存/IP）
   - 系统更新与清理
   - SSH 端口与密码安全配置
   - Docker 容器管理（安装/查看/重启）

使用指南

快速开始

# 下载脚本
wget -O vpsgj.sh https://raw.githubusercontent.com/chengege666/bbr-gj/main/vpsgj.sh

# 授予执行权限
chmod +x vpsgj.sh

# 以 root 权限运行
sudo ./vpsgj.sh

主菜单功能

1) BBR 综合测速
2) 安装/切换 BBR 内核
3) 查看系统信息
4) 系统更新
5) 系统清理
6) Docker 容器管理
7) SSH 端口与密码修改
8) 卸载脚本

注意事项

⚠️ 重要安全提示

- 修改 SSH 端口后需立即使用新端口重新连接
- 系统更新可能影响服务稳定性，建议在维护窗口操作

📝 卸载说明

使用选项 8 可彻底卸载脚本及相关文件，卸载记录保存在 
"vpsgj_uninstall_done.txt"

技术支持

GitHub 项目

"https://github.com/chengege666/bbr-gj" (https://github.com/chengege666/bbr-gj)

依赖组件

- speedtest-cli (网络测速)
- curl/wget/git (脚本依赖)
- net-tools (网络工具)

© 2023 VPS 工具箱项目组 | GPL-3.0 License

"工具版本: v2.0 | 最后更新: 2023-10-15"
