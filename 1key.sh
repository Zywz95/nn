#!/bin/bash

# 定义下载URL和解压目录
DOWNLOAD_URL="https://ghfast.top/https://raw.githubusercontent.com/Zywz95/nn/5f9f6a755a6fc035dda6093e8fd4fa7a0254256c/0.zip"  # 替换为实际下载链接
TARGET_DIR="/root/nock"
CONFIG_FILE="config.yaml"
SERVICE_NAME="nock.service"

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
  echo "错误: 需要root权限操作/root目录"
  echo "请使用: sudo $0"
  exit 1
fi

# 1. 下载和解压流程（同上）
ZIP_FILE=$(mktemp)
curl -fsSL -o "$ZIP_FILE" "$DOWNLOAD_URL" || {
  echo "下载失败"; exit 1
}
unzip -DD -q -o "$ZIP_FILE" -d "$TARGET_DIR" || {
  echo "解压失败"; rm -f "$ZIP_FILE"; exit 1
}
rm -f "$ZIP_FILE"
find "$TARGET_DIR" -type f \( -name "*.sh" -o -perm -u=x \) -exec chmod +x {} \;

# 2. 修改配置文件（同上）
cd "$TARGET_DIR" || exit 1
threads=$(nproc)
target_threads=$((threads > 1 ? threads - 1 : 0))
sed -i.bak "s/^\(\s*threads\s*:\s*\)[0-9]\+/\1$target_threads/" "$CONFIG_FILE"

# 3. 创建Systemd服务
cat > "/etc/systemd/system/$SERVICE_NAME" << EOF
[Unit]
Description=Nock
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$TARGET_DIR
ExecStart=/bin/bash -c 'sed -i "s/^\(\s*threads\s*:\s*\)[0-9]\+/\1$(($(nproc)-1))/" "$TARGET_DIR/config.yaml" && exec "$TARGET_DIR/h9-miner-nock-linux-amd64"'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 4. 重载systemd并启用服务
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" --now
systemctl restart "$SERVICE_NAME"

# 5. 检查服务状态
echo -e "\n服务状态:"
systemctl status "$SERVICE_NAME" --no-pager -l

# 6. 查看日志
echo -e "\n最新日志:"
journalctl -u "$SERVICE_NAME" -n 10 --no-pager --since "1 min ago"