# ---- build stage ----
FROM golang:1.26-alpine AS build
WORKDIR /src

ARG SERVER_VERSION=dev

# 先拷贝依赖清单,利用 Docker layer 缓存
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# CGO_ENABLED=0:纯 Go SQLite(modernc),静态编译进 scratch
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath       -ldflags="-s -w -X main.serverVersion=${SERVER_VERSION}"       -o /out/sync-server .  && CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w"       -o /out/bootstrap ./bootstrap

# ---- runtime stage ----
FROM scratch
COPY --from=build /out/bootstrap /bootstrap
COPY --from=build /out/sync-server /sync-server

# bootstrap 优先执行 /data/sync-server(管理页上传的热更新版本),实现更新跨重启持久。
ENTRYPOINT ["/bootstrap"]

# 配置:必填 ADMIN_PASSWORD(或挂载 /config.json);可选 SYNC_TOKEN 作为旧数据迁移种子。
# 数据目录:SQLite + book-vault/ 书文件 + 热更新二进制,部署时挂载卷持久化。
VOLUME /data
ENV SYNC_DB_PATH=/data/sync.db

EXPOSE 8080
