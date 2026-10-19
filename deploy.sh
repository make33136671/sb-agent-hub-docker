#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  赛博客服系统 - Docker 部署脚本
#  使用 PostgreSQL + Redis + Nginx 单容器方案
# ═══════════════════════════════════════════════════════════════

set -e

cd "$(dirname "$0")"

# ── 1. 检查 .env 文件，不存在则自动生成 ──
if [ ! -f .env ]; then
    echo "→ 首次部署，自动生成配置..."
    PG_PASS=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)
    JWT_ADMIN=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 64)
    JWT_API=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 64)

    cat > .env << EOF
# ═════════════════════════════════════════════════════════
#  赛博客服系统单容器部署配置（自动生成）
# ═════════════════════════════════════════════════════════

# 项目名（影响容器名、数据库名、Redis前缀）
PROJECT_NAME=agenthub

# API DLL 文件名
APP_DLL_NAME=Sb.Apps.AgentHub.WebApi.dll

# 对外端口（四端口分离，9000 段）
CHAT_PORT=9000
ADMIN_PORT=9001
API_PORT=9002
WIDGET_PORT=9003

# PostgreSQL（密码已自动生成）
POSTGRES_DB=sb_agent_hub
POSTGRES_PASSWORD=${PG_PASS}

# JWT 密钥（已自动生成）
JWT_ADMIN_KEY=${JWT_ADMIN}
JWT_API_KEY=${JWT_API}

# 默认管理员账号（首次启动自动创建）
DEFAULT_ADMIN_USER=admin
DEFAULT_ADMIN_PASS=admin123

# 强制 HTTPS/WSS（默认开启，反向代理后协议识别有问题时保持 true）
FORCE_HTTPS=true

# 数据持久化
# 留空 = Docker 命名卷（内置）
# 填路径 = 绑定挂载到宿主目录（外置）
#   POSTGRES_DATA_PATH=./data/postgresql
#   REDIS_DATA_PATH=./data/redis
#   UPLOAD_DATA_PATH=./data/upload
POSTGRES_DATA_PATH=
REDIS_DATA_PATH=
UPLOAD_DATA_PATH=
EOF
    echo "✓ .env 配置文件已生成"
    echo "  PostgreSQL 密码: ${PG_PASS}"
    echo "  （密码也可在 .env 文件中查看）"
else
    echo "✓ .env 配置文件已存在，跳过生成"
fi

# ── 2. 构建镜像并启动容器 ──
echo ""
echo "→ 构建 Docker 镜像（首次约 3~5 分钟）..."
docker compose up -d --build

# ── 3. 等待启动 ──
echo "→ 等待服务启动（约 30 秒）..."
sleep 30

# ── 4. 检查状态 ──
echo ""
if docker compose exec app curl -s http://localhost:6010/health > /dev/null 2>&1; then
    echo "✓ 服务启动成功！"
else
    echo "→ 等待 API 就绪（额外 30 秒）..."
    sleep 30
    if docker compose exec app curl -s http://localhost:6010/health > /dev/null 2>&1; then
        echo "✓ 服务启动成功！"
    else
        echo "✗ 服务启动失败，请检查日志："
        echo "  docker compose logs"
        exit 1
    fi
fi

echo ""
echo "══════════════════════════════════════════════"
echo "  赛博客服系统已部署完成！"
echo ""
echo "  访客聊天端:   http://localhost:9000"
echo "  管理后台:     http://localhost:9001"
echo "  API 直通:      http://localhost:9002"
echo "  Widget 挂件:   http://localhost:9003"
echo ""
echo "  默认管理员:   admin / admin123"
echo "  数据库密码:   $(grep POSTGRES_PASSWORD .env | cut -d= -f2)"
echo "══════════════════════════════════════════════"
