#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 检查root权限
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}此脚本需要root权限运行${NC}"
    exit 1
fi

# 检查必要文件和目录
check_prerequisites() {
    local missing_files=0
    
    if [ ! -d "/etc/sing-box" ]; then
        echo -e "${RED}错误: /etc/sing-box 目录不存在${NC}"
        missing_files=1
    fi
    
    if [ ! -f "/etc/sing-box/mode.conf" ]; then
        echo -e "${RED}错误: mode.conf 文件不存在${NC}"
        missing_files=1
    fi
    
    if [ ! -d "/etc/sing-box/scripts" ]; then
        echo -e "${RED}错误: scripts 目录不存在${NC}"
        missing_files=1
    fi
    
    if [ $missing_files -eq 1 ]; then
        exit 1
    fi
}

# 应用防火墙规则
apply_firewall() {
    local MODE
    MODE=$(grep -oE '^MODE=.*' /etc/sing-box/mode.conf | cut -d'=' -f2)
    if [ "$MODE" = "TProxy" ]; then
        echo -e "${GREEN}应用 TProxy 模式下的防火墙规则...${NC}"
        bash /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        echo -e "${GREEN}应用 TUN 模式下的防火墙规则...${NC}"
        bash /etc/sing-box/scripts/configure_tun.sh
    else
        echo -e "${RED}错误: 无效的模式配置${NC}"
        return 1
    fi
}

# 创建启动脚本
create_startup_script() {
    cat > /etc/init.d/sing-box-startup <<'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=15
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/bin/sing-box run -c /etc/sing-box/config.json
    procd_set_param respawn
    procd_set_param stderr 1
    procd_set_param stdout 1
    procd_close_instance
    
    # 等待服务完全启动
    sleep 3
    
    # 读取模式并应用防火墙规则
    MODE=$(grep -oE '^MODE=.*' /etc/sing-box/mode.conf | cut -d'=' -f2)
    if [ "$MODE" = "TProxy" ]; then
        /etc/sing-box/scripts/configure_tproxy.sh
    elif [ "$MODE" = "TUN" ]; then
        /etc/sing-box/scripts/configure_tun.sh
    fi
}

stop_service() {
    # 停止服务前清理防火墙规则
    MODE=$(grep -oE '^MODE=.*' /etc/sing-box/mode.conf | cut -d'=' -f2)
    if [ "$MODE" = "TProxy" ]; then
        /etc/sing-box/scripts/clean_nft.sh
    elif [ "$MODE" = "TUN" ]; then
        /etc/sing-box/scripts/clean_nft.sh
    fi
}
EOF

    chmod +x /etc/init.d/sing-box-startup
}

# 主菜单
echo -e "${GREEN}sing-box 开机自启动管理${NC}"
echo "请选择操作:"
echo "1: 启用自启动"
echo "2: 禁用自启动"
read -rp "请输入选项 (1/2): " autostart_choice

case $autostart_choice in
    1)
        # 检查先决条件
        check_prerequisites
        
        # 检查自启动状态
        if [ -f /etc/rc.d/S99sing-box-startup ]; then
            echo -e "${YELLOW}自启动已经启用，无需操作${NC}"
            exit 0
        fi

        echo -e "${GREEN}正在启用自启动...${NC}"
        
        # 创建并启用启动脚本
        create_startup_script
        /etc/init.d/sing-box-startup enable
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}自启动配置成功${NC}"
            echo -e "${GREEN}正在启动服务...${NC}"
            /etc/init.d/sing-box-startup start
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}服务启动成功${NC}"
            else
                echo -e "${RED}服务启动失败，请检查日志${NC}"
            fi
        else
            echo -e "${RED}启用自启动失败${NC}"
        fi
        ;;
        
    2)
        if [ ! -f /etc/rc.d/S99sing-box-startup ]; then
            echo -e "${YELLOW}自启动已经禁用，无需操作${NC}"
            exit 0
        fi

        echo -e "${GREEN}正在禁用自启动...${NC}"
        
        # 停止并禁用服务
        /etc/init.d/sing-box-startup stop
        /etc/init.d/sing-box-startup disable
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}自启动已成功禁用${NC}"
        else
            echo -e "${RED}禁用自启动失败${NC}"
        fi
        ;;
        
    *)
        echo -e "${RED}无效的选择${NC}"
        exit 1
        ;;
esac