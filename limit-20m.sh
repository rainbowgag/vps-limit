#!/bin/bash
set -e

echo "===================================="
echo " VPS 限速脚本（稳定版 tc + cake）"
echo " 请输入需要限制的带宽（单位：Mbps）"
echo " 示例：15 表示限速 15M"
echo "===================================="
read -r SPEED

# 去除前导和尾随空白字符
SPEED=$(echo "$SPEED" | xargs)

# 输入校验（只允许正整数）
case "$SPEED" in
  ''|*[!0-9]*)
    echo "❌ 输入无效，请输入正整数，例如 15"
    exit 1
    ;;
esac

if [ "$SPEED" -le 0 ]; then
  echo "❌ 输入必须大于 0"
  exit 1
fi

# 自动识别主网卡
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

echo "------------------------------------"
echo "检测到主网卡: $IFACE"
echo "设置限速: ${SPEED} Mbps（上下行）"
echo "------------------------------------"

# 清理旧规则
tc qdisc del dev "$IFACE" root 2>/dev/null || true
tc qdisc del dev "$IFACE" ingress 2>/dev/null || true

# 下行限速
tc qdisc add dev "$IFACE" root cake bandwidth "${SPEED}Mbit"

# 上行限速（ingress + ifb）
modprobe ifb || true
ip link add ifb0 type ifb 2>/dev/null || true
ip link set ifb0 up

tc qdisc add dev "$IFACE" handle ffff: ingress
tc filter add dev "$IFACE" parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0
tc qdisc add dev ifb0 root cake bandwidth "${SPEED}Mbit"

# 写 systemd 服务
cat > /etc/systemd/system/vps-limit.service <<EOF
[Unit]
Description=VPS Bandwidth Limit (${SPEED}Mbps)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "\
IFACE=\$(ip route get 1.1.1.1 2>/dev/null | awk '{print \$5; exit}'); \
if [ -z \"\$IFACE\" ]; then \
  echo 'Error: Cannot detect network interface'; \
  exit 1; \
fi; \
tc qdisc del dev \$IFACE root 2>/dev/null || true; \
tc qdisc del dev \$IFACE ingress 2>/dev/null || true; \
tc qdisc add dev \$IFACE root cake bandwidth ${SPEED}Mbit || exit 1; \
modprobe ifb || true; \
ip link add ifb0 type ifb 2>/dev/null || true; \
ip link set ifb0 up || exit 1; \
tc qdisc add dev \$IFACE handle ffff: ingress || exit 1; \
tc filter add dev \$IFACE parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0 || exit 1; \
tc qdisc add dev ifb0 root cake bandwidth ${SPEED}Mbit || exit 1"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vps-limit
systemctl start vps-limit

echo "===================================="
echo "✅ 已成功限速为 ${SPEED} Mbps（上下行）"
echo "验证命令: speedtest"
echo "查看规则: tc qdisc show dev $IFACE"
echo "===================================="
