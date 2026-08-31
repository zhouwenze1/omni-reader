# Omni Reader 进度同步服务器

Go 单二进制 HTTP 服务,配合 Flutter 双端(移动/桌面)"阅读同步"功能使用。
SQLite 存储,last-write-wins 合并,设备闲置自动清理。

## 快速开始(Docker 推荐)

```bash
# 1. 编辑 docker-compose.yml,把 SYNC_TOKEN 换成你自己的随机串(双端配置同一个)
# 2. 构建并启动
docker compose up -d --build

# 3. 验证
curl http://<vps-ip>:8080/health
# => {"ok":true}
```

- 数据存在命名卷 `sync-data`,升级镜像不丢进度
- 防火墙/安全组放行 8080
- 想加 HTTPS:前面套一层 nginx/caddy 反代即可

## 原生部署(Ubuntu systemd)

```bash
# 1. 本机(Windows)交叉编译出 Linux 二进制
go build -o sync-server .          # 或 CGO_ENABLED=0 GOOS=linux go build -o sync-server .
# 2. 上传到 VPS
scp sync-server config.example.json user@vps:/opt/sync-server/
# 3. 配置 token
ssh user@vps 'cp /opt/sync-server/config.example.json /opt/sync-server/config.json && nano /opt/sync-server/config.json'
# 4. 装 systemd 服务
sudo cp deploy/omni-sync.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now omni-sync
```

## 配置

| 项 | config.json | 环境变量 | 说明 |
| --- | --- | --- | --- |
| token | `token` | `SYNC_TOKEN` | 必填,双端认证用 |
| 端口 | `port` | `SYNC_PORT` | 默认 8080 |
| 数据库路径 | `db_path` | `SYNC_DB_PATH` | Docker 默认 `/data/sync.db` |
| 设备闲置天数 | `device_inactive_days` | `SYNC_DEVICE_INACTIVE_DAYS` | 默认 180 天,到期自动清理设备记录 |

环境变量优先于 config.json。

## API

```
GET  /health                          # 健康检查(无需 token)
POST /api/sync/push                   # 批量推送进度
GET  /api/sync/pull?after=&deviceId=  # 拉增量(updatedAt > after)
GET  /api/sync/pull?bookUid=&deviceId= # 拉单书(不受 after 限制)
```

除 `/health` 外均需请求头 `Authorization: Bearer <token>`。

## 测试

```bash
go test ./...
```
