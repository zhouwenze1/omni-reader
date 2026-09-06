# Omni Reader 同步服务器(进度同步 + 书库云备份)

Go 单二进制 HTTP 服务,配合 Flutter 双端(移动/桌面)"云端同步"使用。
SQLite 存储,**多用户**(管理员网页发放 token,数据按 token 隔离),
阅读进度按内容变化写入变更日志,cursor 增量拉取,设备闲置自动清理。

## 快速开始(Docker 推荐)

```bash
# 1. 编辑 docker-compose.yml,设置 ADMIN_PASSWORD
# 2. 构建并启动
docker compose up -d --build

# 3. 打开管理页生成用户 token 并分发给设备
#    http://<vps-ip>:8080/admin
# 4. 验证
curl http://<vps-ip>:8080/health
# => {"ok":true}
```

- 数据存在命名卷 `sync-data`(SQLite + `book-vault/` 书文件),升级镜像不丢
- 防火墙/安全组放行 8080
- 想加 HTTPS:前面套一层 nginx/caddy 反代即可

## 管理页(/admin)

浏览器打开 `http://<host>:8080/admin`,用 `ADMIN_PASSWORD` 登录:

- 生成用户 token(起名便于识别,如"测试-平板"),创建后一键复制分发
- 查看每个用户的书目数、书文件占用、最近活跃时间
- 删除用户(同时清除该用户全部同步数据与云端书文件)

会话有效期 7 天,登录失败有 1 秒延迟防爆破。

## 原生部署(Ubuntu systemd)

```bash
# 1. 本机(Windows)交叉编译出 Linux 二进制
CGO_ENABLED=0 GOOS=linux go build -o sync-server .
# 2. 上传到 VPS
scp sync-server config.example.json user@vps:/opt/sync-server/
# 3. 配置(至少设置 admin_password)
ssh user@vps 'cd /opt/sync-server && cp config.example.json config.json && nano config.json'
# 4. 装 systemd 服务
sudo cp deploy/omni-sync.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now omni-sync
```

## 配置

| 项 | config.json | 环境变量 | 说明 |
| --- | --- | --- | --- |
| 管理密码 | `admin_password` | `ADMIN_PASSWORD` | **必填**,管理页登录 |
| 旧版种子 token | `token` | `SYNC_TOKEN` | 可选;首次启动用该 token 建 default 用户,升级部署保留可延续旧数据 |
| 端口 | `port` | `SYNC_PORT` | 默认 8080 |
| 数据库路径 | `db_path` | `SYNC_DB_PATH` | Docker 默认 `/data/sync.db`;书文件存同目录 `book-vault/` |
| 设备闲置天数 | `device_inactive_days` | `SYNC_DEVICE_INACTIVE_DAYS` | 默认 180 天,到期自动清理设备记录 |
| 单书文件上限 | `book_vault_max_file_mb` | `SYNC_BOOK_MAX_FILE_MB` | 默认 200MB,超限拒绝上传(413) |

环境变量优先于 config.json。多用户数据按 token 隔离:进度、设备、书单、书文件均互不可见。

## API

```
GET  /health                          # 健康检查(无需 token)
POST /api/sync/push                   # 批量推送进度
GET  /api/sync/pull?cursor=&deviceId= # 按服务端 seq 拉增量
GET  /api/sync/pull?bookUid=&deviceId=# 拉单书当前状态,不推进全局 cursor
GET  /api/library/manifest?since=<ms> # 书单(含墓碑),since 增量
POST /api/library/announce            # 上报书目元数据(含封面 base64)
PUT  /api/books/{uid}/file?ext=epub   # 上传原始书文件
GET  /api/books/{uid}/file            # 下载原始书文件(支持 Range)
GET  /api/books/{uid}/cover           # 下载封面
DELETE /api/library/{uid}             # 删除云端书目(墓碑)+文件
```

除 `/health` 与 `/admin` 登录外均需请求头 `Authorization: Bearer <用户token>`。

推送仍使用原有进度字段。服务端只在 `locator` 或 `progression` 变化时写入
`progress_sync` 和 `sync_changes`;重复推送相同阅读位置是幂等操作。
旧客户端的 `after` 参数仍保留兼容,新客户端必须使用 `cursor`。

旧库升级:首次用新版本启动时,历史进度/设备记录自动迁移归属到 default 用户
(由旧配置 `token`/`SYNC_TOKEN` 播种);书单与书文件从零开始。

## 测试

```bash
go test ./...
```
