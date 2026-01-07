#!/bin/bash
set -e

echo "===================================="
echo " VPS 限速脚本（云 VPS 最终稳定版）"
echo " - IFB + cake"
echo " - 上下行同时限速"
echo " - 兼容 curl | bash 执行方式"
echo "===================================="

# ⚠️ 关键：强制从终端读取输入
if [ -t 0 ]; then
  read -p "请输入限速值（单位：Mbps，将同时限制上下行）: " SPEED
else
  read -p "请输入限速值（单位：Mbps，将同时限制上下行）: " SPEED < /dev/tty
fi

# 清洗输入：去除所有非数字字符，包括空格、换行等
SPEED=$(echo "$SPEED" | tr -d '[:space:]' | tr -cd '0-9')

# 验证输入
if [ -z "$SPEED" ] || [ "$SPEED" = "0" ] || ! [ "$SPEED" -gt 0 ] 2>/dev/null; then
  echo "❌ 请输入有效的正整数，例如 15"
  exit 1
fi

# 自动识别主网卡
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

echo "------------------------------------"
echo "主网卡: $IFACE"
echo "限速值: ${SPEED} Mbps（上下行）"
echo "------------------------------------"

# 1️⃣ 清理旧规则
tc qdisc del dev "$IFACE" root 2>/dev/null || true
tc qdisc del dev "$IFACE" ingress 2>/dev/null || true
tc qdisc del dev ifb0 root 2>/dev/null || true
ip link del ifb0 2>/dev/null || true

# 2️⃣ 创建 IFB
modprobe ifb || true
ip link add ifb0 type ifb 2>/dev/null || true
ip link set ifb0 up

# 3️⃣ 上行限速（root qdisc）
tc qdisc add dev "$IFACE" root cake bandwidth "${SPEED}Mbit"

# 4️⃣ 下行限速（ingress → IFB）
tc qdisc add dev "$IFACE" handle ffff: ingress
tc filter add dev "$IFACE" parent ffff: protocol ip u32 match u32 0 0 \
  action mirred egress redirect dev ifb0

# 5️⃣ 在 IFB 上限速（下载流量）
tc qdisc add dev ifb0 root cake bandwidth "${SPEED}Mbit"

echo "===================================="
echo "✅ 限速 ${SPEED} Mbps（上下行）已生效"
echo "验证：speedtest"
echo "查看上行：tc qdisc show dev $IFACE"
echo "查看下行：tc qdisc show dev ifb0"
echo "===================================="
