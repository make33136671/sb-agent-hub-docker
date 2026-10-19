FROM mcr.microsoft.com/dotnet/aspnet:10.0

# 安装所有服务（Nginx + PostgreSQL + Redis + Supervisor）
RUN apt-get update -o Acquire::Retries=5 && \
    apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        postgresql \
        redis-server \
        curl \
    && rm -rf /var/lib/apt/lists/*

# 创建 PostgreSQL 版本无关的 bin 路径
RUN PG_VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1) && \
    ln -s /usr/lib/postgresql/${PG_VER}/bin /usr/lib/postgresql/bin

# 启用 Nginx 默认站点
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# 复制编译产物
WORKDIR /app
COPY api/app/ /app/api/
COPY admin-ui/html/ /app/admin-ui/
COPY chat-ui/html/ /app/chat-ui/
COPY widget/ /app/widget/

# 复制配置
COPY nginx/default.conf /etc/nginx/sites-available/default
COPY postgresql/postgresql.conf /etc/postgresql/postgresql.conf
COPY redis/redis.conf /etc/redis/redis.conf
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/app.conf /etc/supervisor/conf.d/app.conf
COPY scripts/start-api.sh /app/start-api.sh
COPY scripts/init-admin.sh /app/scripts/init-admin.sh
COPY entrypoint.sh /entrypoint.sh

# 权限 + 修复 Windows 行尾
RUN sed -i 's/\r$//' /entrypoint.sh /app/start-api.sh /app/scripts/init-admin.sh && \
    chmod +x /app/start-api.sh /app/scripts/init-admin.sh /entrypoint.sh && \
    chown -R www-data:www-data /app/admin-ui /app/chat-ui /app/widget && \
    mkdir -p /var/lib/postgresql/data /var/lib/redis /var/log/supervisor /app/api/wwwroot/upload && \
    chown -R postgres:postgres /var/lib/postgresql && \
    chown -R redis:redis /var/lib/redis && \
    chmod 777 /app/api/wwwroot/upload 2>/dev/null || true

EXPOSE 9000 9001 9002 9003

ENTRYPOINT ["/entrypoint.sh"]
