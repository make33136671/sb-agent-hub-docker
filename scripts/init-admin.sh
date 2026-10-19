#!/bin/bash
# 初始化默认管理员账号（首次启动时自动执行）
# 在后台运行，等待 PostgreSQL 就绪 + 表创建完成后插入默认管理员

PG_BIN="/usr/lib/postgresql/bin"
PG_DB="${POSTGRES_DB:-sb_agent_hub}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
ADMIN_USER="${DEFAULT_ADMIN_USER:-admin}"
ADMIN_PASS="${DEFAULT_ADMIN_PASS:-admin123}"

# 最多等待 60 秒
MAX_WAIT=60
WAITED=0

echo "[init-admin] 等待 PostgreSQL 就绪..."
while ! $PG_BIN/psql -h 127.0.0.1 -p 5432 -U postgres -d "$PG_DB" -c "SELECT 1" >/dev/null 2>&1; do
    sleep 2
    WAITED=$((WAITED + 2))
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "[init-admin] 等待 PostgreSQL 超时，退出"
        exit 1
    fi
done
echo "[init-admin] PostgreSQL 就绪"

# 等待管理员表创建（由 API 启动时 SyncStructure 创建）
echo "[init-admin] 等待管理员表创建..."
WAITED=0
while ! $PG_BIN/psql -h 127.0.0.1 -p 5432 -U postgres -d "$PG_DB" -c "SELECT 1 FROM sb_agenthub_admin LIMIT 1" >/dev/null 2>&1; do
    sleep 2
    WAITED=$((WAITED + 2))
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "[init-admin] 等待管理员表超时，退出"
        exit 1
    fi
done
echo "[init-admin] 管理员表已存在"

# 检查表是否为空
count=$($PG_BIN/psql -h 127.0.0.1 -p 5432 -U postgres -d "$PG_DB" -t -c "SELECT count(*) FROM sb_agenthub_admin WHERE \"IsDeleted\" = false;" | xargs)

if [ "$count" = "0" ]; then
    echo "[init-admin] 管理员表为空，创建默认管理员: $ADMIN_USER / $ADMIN_PASS"

    # 插入默认超级管理员（RoleId=1 超级管理员，明文密码，首次登录后修改会自动加密）
    $PG_BIN/psql -h 127.0.0.1 -p 5432 -U postgres -d "$PG_DB" <<EOF
INSERT INTO sb_agenthub_admin
  ("ParentId", "Username", "Password", "RoleId", "Name", "Status", "CreateTime", "IsDeleted")
VALUES
  (0, '$ADMIN_USER', '$ADMIN_PASS', 1, '超级管理员', 'Active', NOW(), false);
EOF

    echo "[init-admin] 默认管理员创建成功"
else
    echo "[init-admin] 管理员表已有 $count 条记录，跳过创建"
fi
