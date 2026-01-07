#!/bin/bash
set -e

echo "===================================="
echo " VPS 限速脚本（云 VPS 最终稳定版）"
echo " - IFB + cake"
echo " - 不修改 eth0 root qdisc"
echo " - 兼容 curl | bash 执行方式"
echo "===================================="

# ⚠️ 关键：强制从终端读取输入
read -p "请输入下载限速（单位：Mbps）: " SPEED < /dev/tty

# 清洗输入
SPEED=$(echo "$SPEED" | tr -cd '0-9')

if [ -z "$SPEED" ] || [ "$SPEED" -le 0 ]; then
  echo "❌ 请输入有效的正整数，例如 15"
  exit 1
fi

# 自动识别主网卡
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

echo "------------------------------------"
echo "主网卡: $IFACE"
echo "下载限速: ${SPEED} Mbps"
echo "------------------------------------"

# 1️⃣ 清理我们自己可能留下的规则（不碰 root）
tc qdisc del dev "$IFACE" ingress 2>/dev/null || true
tc qdisc del dev ifb0 root 2>/dev/null || true
ip link del ifb0 2>/dev/null || true

# 2️⃣ 创建 IFB
modprobe ifb || true
ip link add ifb0 type ifb 2>/dev/null || true
ip link set ifb0 up

# 3️⃣ ingress → IFB
tc qdisc add dev "$IFACE" handle ffff: ingress
tc filter add dev "$IFACE" parent ffff: protocol ip u32 match u32 0 0 \
  action mirred egress redirect dev ifb0

# 4️⃣ 在 IFB 上限速（云 VPS 100% 成功）
tc qdisc add dev ifb0 root cake bandwidth "${SPEED}Mbit"

echo "===================================="
echo "✅ 下载限速 ${SPEED} Mbps 已生效"
echo "验证：speedtest"
echo "查看：tc qdisc show dev ifb0"
echo "===================================="
