#!/bin/bash
set -e

PG_BIN="/usr/lib/postgresql/bin"
PG_DATA="/var/lib/postgresql/data"
PG_DB="${POSTGRES_DB:-sb_agent_hub}"

# 修复挂载卷的权限
chown -R postgres:postgres /var/lib/postgresql 2>/dev/null || true
chown -R redis:redis /var/lib/redis 2>/dev/null || true
mkdir -p /root/.aspnet/DataProtection-Keys
mkdir -p /app/api/wwwroot/upload
chmod 777 /app/api/wwwroot/upload 2>/dev/null || true

# 首次运行：初始化 PostgreSQL
if [ ! -f "$PG_DATA/PG_VERSION" ]; then
    echo "→ Initializing PostgreSQL..."
    mkdir -p "$PG_DATA"
    chown -R postgres:postgres /var/lib/postgresql
    su postgres -c "$PG_BIN/initdb -D $PG_DATA --auth=trust --encoding=UTF8"

    # 临时启动 PostgreSQL 来设置密码和建库（通过 TCP 连接，避免 socket 路径问题）
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w -o '-c listen_addresses=127.0.0.1 -p 5432' start"
    su postgres -c "$PG_BIN/psql -h 127.0.0.1 -p 5432 -c \"ALTER USER postgres PASSWORD '${POSTGRES_PASSWORD}';\""
    su postgres -c "$PG_BIN/createdb -h 127.0.0.1 -p 5432 ${PG_DB}" 2>/dev/null || true
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w stop"

    # 配置 pg_hba.conf：本地 trust，远程 md5
    cat > "$PG_DATA/pg_hba.conf" << 'EOF'
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF
    chown postgres:postgres "$PG_DATA/pg_hba.conf"

    echo "✓ PostgreSQL initialized (database: ${PG_DB})"
else
    # 非首次运行：同步密码 + 确保数据库存在
    echo "→ Ensuring PostgreSQL database and password..."
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w -o '-c listen_addresses=127.0.0.1 -p 5432' start" 2>/dev/null || true
    # 使用 Unix socket（local trust）连接，无需密码
    su postgres -c "$PG_BIN/psql -p 5432 -c \"ALTER USER postgres PASSWORD '${POSTGRES_PASSWORD}';\"" 2>/dev/null || true
    su postgres -c "$PG_BIN/psql -p 5432 -lqt" | cut -d\| -f1 | grep -qw "${PG_DB}" || \
        su postgres -c "$PG_BIN/createdb -p 5432 ${PG_DB}" 2>/dev/null || true
    su postgres -c "$PG_BIN/pg_ctl -D $PG_DATA -w stop" 2>/dev/null || true
    echo "✓ PostgreSQL ready (database: ${PG_DB})"
fi

echo "→ Starting all services (nginx + postgresql + redis + api)..."

# 后台运行：等待 API 建表完成后创建默认管理员（仅首次启动需要）
bash /app/scripts/init-admin.sh &

exec supervisord -n -c /etc/supervisor/supervisord.conf
