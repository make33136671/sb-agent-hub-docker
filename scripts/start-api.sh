#!/bin/bash
set -e

export ASPNETCORE_ENVIRONMENT=Production
export ASPNETCORE_URLS=http://+:6010

# 数据库配置（PostgreSQL）
# 两套变量同时设置：
#   1. DB_* 系列 —— 供框架 appsettings.json 中 ${DB_PORT|3306} 占位符替换使用
#   2. DbConfig__* 系列 —— 供 ASP.NET Core 标准配置绑定使用
export DB_TYPE=PostgreSql
export DB_SERVER=localhost
export DB_PORT=5432
export DB_NAME=${POSTGRES_DB:-sb_agent_hub}
export DB_USER=postgres
export DB_PASSWORD=${POSTGRES_PASSWORD}

export DbConfig__DbType=PostgreSql
export DbConfig__Server=localhost
export DbConfig__Port=5432
export DbConfig__Database=${POSTGRES_DB:-sb_agent_hub}
export DbConfig__User=postgres
export DbConfig__Password=${POSTGRES_PASSWORD}

# Redis 配置
export CacheConfig__Provider=Redis
export "CacheConfig__Redis__Connection=localhost:6379"
export "CacheConfig__Redis__InstanceName=${PROJECT_NAME:-agenthub}:"

# 上传配置（URL 前缀，物理目录 = {ContentRoot}/wwwroot/upload）
export UploadConfig__UploadPath=/upload/

# 云端中心地址（数据库备份上传接收端根地址）
export CloudConfig__ServerUrl=${CLOUD_SERVER_URL:-https://cloud.saibo.club}

echo "→ Waiting for PostgreSQL..."
until PGPASSWORD="${POSTGRES_PASSWORD}" psql -h 127.0.0.1 -U postgres -d "${POSTGRES_DB:-sb_agent_hub}" -c "SELECT 1;" &>/dev/null; do
    sleep 1
done
echo "✓ PostgreSQL ready."

echo "→ Waiting for Redis..."
until redis-cli ping 2>/dev/null | grep -q PONG; do
    sleep 1
done
echo "✓ Redis ready."

cd /app/api

# 确保 installed.lock 存在，让框架走完整装配模式（含建表/种子数据/健康检查等）
if [ ! -f "installed.lock" ]; then
    touch installed.lock
    echo "✓ Created installed.lock (first run)"
fi

echo "→ Starting .NET API..."
exec dotnet "${APP_DLL_NAME:-Sb.Apps.AgentHub.WebApi.dll}"
