#!/bin/bash
set -e

echo "===================================="
echo " VPS 限速脚本（交互式）"
echo " 请输入需要限制的带宽（单位：Mbps）"
echo " 示例：20 表示限速 20M"
echo "===================================="
read -p "请输入限速数值（Mbps）: " SPEED

# 校验输入
if ! [[ "$SPEED" =~ ^[0-9]+$ ]] || [ "$SPEED" -le 0 ]; then
  echo "❌ 输入无效，请输入正整数，例如 20"
  exit 1
fi

# Mbps 转 Kbps
DOWN=$((SPEED * 1000))
UP=$((SPEED * 1000))

# 自动识别主网卡
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

echo "------------------------------------"
echo "检测到主网卡: $IFACE"
echo "设置限速: ${SPEED} Mbps（上下行）"
echo "------------------------------------"

# 安装 wondershaper
apt update -y
apt install -y wondershaper

# 清理旧规则
wondershaper clear $IFACE || true

# 设置限速
wondershaper $IFACE $DOWN $UP

# 写入 systemd 开机自启
cat > /etc/systemd/system/wondershaper-limit.service <<EOF
[Unit]
Description=VPS Bandwidth Limit (${SPEED}Mbps)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/wondershaper $IFACE $DOWN $UP
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wondershaper-limit
systemctl start wondershaper-limit

echo "===================================="
echo "✅ VPS 已成功限速为 ${SPEED} Mbps（上下行）"
echo "查看状态: wondershaper show $IFACE"
echo "解除限速: wondershaper clear $IFACE"
echo "===================================="
