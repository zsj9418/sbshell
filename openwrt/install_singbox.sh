#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 检查 sing-box 是否已安装
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box 已安装，跳过安装步骤${NC}"
else
    # 更新包列表并安装必要的依赖和 sing-box
    echo "正在更新包列表并安装 sing-box,请稍候..."
    opkg update >/dev/null 2>&1
    opkg install sing-box >/dev/null 2>&1

    if command -v sing-box &> /dev/null; then
        echo -e "${CYAN}sing-box 安装成功${NC}"
    else
        echo -e "${RED}sing-box 安装失败，请检查日志或网络配置${NC}"
        exit 1
    fi
fi

# 启用并启动 sing-box 服务
/etc/init.d/sing-box enable
/etc/init.d/sing-box start

echo -e "${CYAN}sing-box 服务已启用并启动${NC}"
