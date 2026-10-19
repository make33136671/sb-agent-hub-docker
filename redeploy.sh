#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "══════════════════════════════════════════════"
echo "  赛博客服系统 Docker 重新部署"
echo "══════════════════════════════════════════════"

# 检查 .env 是否存在
if [ ! -f .env ]; then
    echo "✗ 未找到 .env 配置文件！"
    echo ""
    echo "  首次部署请运行: bash deploy.sh"
    echo "  它会自动生成 .env（含数据库密码和端口配置）"
    exit 1
fi

# 加载环境变量
set -a
source .env
set +a

echo "→ 停止旧容器..."
docker compose down

echo ""
echo "→ 重新构建镜像..."
# 如需强制从头构建（忽略缓存），请手动执行: docker compose build --no-cache
docker compose build

echo ""
echo "→ 启动新容器..."
docker compose up -d

echo ""
echo "→ 等待服务就绪..."
sleep 30

echo ""
if docker compose exec app curl -s http://localhost:6010/health > /dev/null 2>&1; then
    echo "✓ 服务就绪！"
else
    echo "→ 等待 API 就绪（额外 30 秒）..."
    sleep 30
fi

echo ""
echo "══════════════════════════════════════════════"
echo "  ✓ 重新部署完成！"
echo ""
echo "  访客聊天端:   http://localhost:${CHAT_PORT:-9000}"
echo "  管理后台:     http://localhost:${ADMIN_PORT:-9001}"
echo "  API 直通:      http://localhost:${API_PORT:-9002}"
echo "  Widget 挂件:   http://localhost:${WIDGET_PORT:-9003}"
echo ""
echo "  PostgreSQL 密码: ${POSTGRES_PASSWORD}"
echo ""
echo "══════════════════════════════════════════════"
echo ""
docker compose ps
echo ""
echo "══════════════════════════════════════════════"
