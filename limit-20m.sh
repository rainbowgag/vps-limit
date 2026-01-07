#!/bin/bash
set -e

echo "===================================="
echo " VPS 限速脚本（tc + cake 最终稳定版）"
echo "===================================="
read -p "请输入限速（Mbps）: " SPEED

case "$SPEED" in
  ''|*[!0-9]*)
    echo "❌ 请输入正整数"
    exit 1
    ;;
esac

IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

echo "网卡: $IFACE"
echo "限速: ${SPEED} Mbps（上下行）"

SCRIPT=/usr/local/bin/vps-limit-apply.sh

cat > $SCRIPT <<EOF
#!/bin/bash

# 下行（replace，避免 Exclusivity 报错）
tc qdisc replace dev $IFACE root cake bandwidth ${SPEED}Mbit

# 上行（ingress）
tc qdisc del dev $IFACE ingress 2>/dev/null || true
modprobe ifb || true
ip link add ifb0 type ifb 2>/dev/null || true
ip link set ifb0 up

tc qdisc replace dev $IFACE handle ffff: ingress
tc filter replace dev $IFACE parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
tc qdisc replace dev ifb0 root cake bandwidth ${SPEED}Mbit
EOF

chmod +x $SCRIPT

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
systemctl restart vps-limit

echo "===================================="
echo "✅ 限速已成功应用"
echo "验证: speedtest"
echo "查看: tc qdisc show dev $IFACE"
echo "===================================="
