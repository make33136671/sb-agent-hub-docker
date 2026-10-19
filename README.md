# 赛博客服系统 Docker 单容器部署模板

基于 SB Framework Docker 模板定制，适用于赛博客服系统（AgentHub）。单容器运行全部服务（Nginx + PostgreSQL + Redis + .NET API）。

## 端口规划（9000 段四端口分离）

| 端口 | 服务 | 用途 |
|------|------|------|
| 9000 | chat-ui + API | 访客聊天端 |
| 9001 | admin-ui + API | 管理后台 |
| 9002 | API 直通 | API 直连 / 第三方对接 |
| 9003 | widget + API | 挂件资源与演示 |

## 使用方法

### 1. 准备编译产物

| 目录 | 内容 | 构建命令示例 |
|------|------|-------------|
| `admin-ui/html/` | 管理后台前端构建产物 | `cd agenthub-admin && pnpm build` → 复制 `apps/web-antd/dist/` 内容 |
| `chat-ui/html/` | 访客聊天端构建产物 | `cd agenthub-chat && pnpm build` → 复制 `dist/` 内容 |
| `widget/` | Widget 挂件构建产物 | `cd agenthub-widget-vue && pnpm build` → 复制 `dist/` 内容 |
| `api/app/` | .NET API 发布产物 | `dotnet publish Sb.Apps.AgentHub.WebApi -c Release -o api/app` |

### 2. 一键部署

```bash
cd agenthub-docker
bash deploy.sh
```

首次运行会自动生成 `.env` 配置文件（含随机 PostgreSQL 密码），请检查配置后重新运行 `bash deploy.sh`。

### 3. 重新部署

代码更新后，重新放入编译产物，然后执行：

```bash
bash redeploy.sh
```

## 目录结构

```
agenthub-docker/
├── 部署教程.html              # 完整部署教程（面向运维）
├── Dockerfile                 # 单容器构建文件
├── docker-compose.yml         # 编排配置
├── deploy.sh                  # 首次部署脚本（生成 .env + 构建启动）
├── redeploy.sh                # 重新部署脚本（更新代码后使用）
├── entrypoint.sh              # 容器入口（PostgreSQL 初始化 + 密码同步）
├── .env.example               # 配置参考（实际 .env 由 deploy.sh 生成）
├── .dockerignore
├── nginx/
│   └── default.conf           # 四端口分离路由（9000/9001/9002/9003）
├── postgresql/
│   └── postgresql.conf        # PostgreSQL 配置
├── supervisor/
│   ├── supervisord.conf       # Supervisor 主配置
│   └── app.conf               # 各服务进程配置（postgresql/redis/nginx/api）
├── redis/
│   └── redis.conf             # Redis 配置
├── scripts/
│   └── start-api.sh           # API 启动脚本（等 PostgreSQL/Redis 就绪后启动）
├── admin-ui/html/             # ← 放入管理后台前端构建产物
├── chat-ui/html/              # ← 放入访客聊天端构建产物
├── widget/                    # ← 放入 Widget 挂件构建产物
└── api/app/                   # ← 放入 .NET API 发布产物
```

## 域名配置示例

在宿主机 Nginx 配置子域名转发到 Docker 容器：

```nginx
# chat.example.com → 访客聊天端
server {
    listen 80;
    server_name chat.example.com;
    location / { proxy_pass http://127.0.0.1:9000; }
}

# admin.example.com → 管理后台
server {
    listen 80;
    server_name admin.example.com;
    location / { proxy_pass http://127.0.0.1:9001; }
}

# api.example.com → API 直通
server {
    listen 80;
    server_name api.example.com;
    location / { proxy_pass http://127.0.0.1:9002; }
}

# widget.example.com → 挂件
server {
    listen 80;
    server_name widget.example.com;
    location / { proxy_pass http://127.0.0.1:9003; }
}
```

SSL 在宿主机或 CDN 层处理，容器不关心证书。

## 数据持久化

默认使用 Docker 命名卷，数据存在 Docker 管理的卷中。如需绑定到宿主目录，编辑 `.env`：

```bash
POSTGRES_DATA_PATH=./data/postgresql
REDIS_DATA_PATH=./data/redis
UPLOAD_DATA_PATH=./data/upload
```

## 常用命令

```bash
# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f

# 查看 API 日志
docker compose logs -f app | grep api

# 进入容器
docker compose exec app bash

# 连接 PostgreSQL
docker compose exec app psql -U postgres -d sb_agent_hub

# 查看容器内各服务状态
docker compose exec app supervisorctl status

# 重启某个服务
docker compose exec app supervisorctl restart api
```

## 打包发布

```bash
# 打包为 tar.gz（包含部署教程和所有配置）
tar -czf agenthub-docker.tar.gz agenthub-docker/
```
