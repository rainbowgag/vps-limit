#!/bin/bash
set -e

# 自动识别主网卡
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

DOWN=20000
UP=20000

echo "检测到主网卡: $IFACE"
echo "设置限速: 下行 ${DOWN}Kbps / 上行 ${UP}Kbps"

apt update -y
apt install -y wondershaper

# 清理旧规则
wondershaper clear $IFACE || true

# 设置限速
wondershaper $IFACE $DOWN $UP

# 写入 systemd 开机自启
cat > /etc/systemd/system/wondershaper-limit.service <<EOF
[Unit]
Description=VPS Bandwidth Limit
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

echo "-------------------------------------"
echo "✅ VPS 已限速为 20Mbps（上下行）"
echo "查看状态: wondershaper show $IFACE"
echo "清除限速: wondershaper clear $IFACE"
echo "-------------------------------------"
