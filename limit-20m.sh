#!/bin/bash
set -e

echo "===================================="
echo " VPS 限速脚本（tc + cake 最终稳定版）"
echo " 请输入需要限制的带宽（单位：Mbps）"
echo " 示例：15 表示限速 15M"
echo "===================================="
read -r SPEED

case "$SPEED" in
  ''|*[!0-9]*)
    echo "❌ 输入无效，请输入正整数"
    exit 1
    ;;
esac

if [ "$SPEED" -le 0 ]; then
  echo "❌ 输入必须大于 0"
  exit 1
fi

IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

echo "检测到主网卡: $IFACE"
echo "设置限速: ${SPEED} Mbps（上下行）"

SCRIPT=/usr/local/bin/vps-limit-apply.sh

# 写真正执行限速的脚本
cat > $SCRIPT <<EOF
#!/bin/bash
tc qdisc del dev $IFACE root 2>/dev/null || true
tc qdisc del dev $IFACE ingress 2>/dev/null || true

tc qdisc add dev $IFACE root cake bandwidth ${SPEED}Mbit

modprobe ifb || true
ip link add ifb0 type ifb 2>/dev/null || true
ip link set ifb0 up

tc qdisc add dev $IFACE handle ffff: ingress
tc filter add dev $IFACE parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
tc qdisc add dev ifb0 root cake bandwidth ${SPEED}Mbit
EOF

chmod +x $SCRIPT

# systemd 只调用脚本
cat > /etc/systemd/system/vps-limit.service <<EOF
[Unit]
Description=VPS Bandwidth Limit (${SPEED}Mbps)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vps-limit
systemctl start vps-limit

echo "===================================="
echo "✅ 限速已应用并已设置开机自启"
echo "验证命令: speedtest"
echo "查看规则: tc qdisc show dev $IFACE"
echo "===================================="
