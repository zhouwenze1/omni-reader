# ---- build stage ----
FROM golang:1.26-alpine AS build
WORKDIR /src

# 先拷贝依赖清单,利用 Docker layer 缓存
COPY go.mod go.sum ./
RUN go mod download

COPY . .
# CGO_ENABLED=0:纯 Go SQLite(modernc),可静态编译进 scratch
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/sync-server .

# ---- runtime stage ----
FROM scratch
COPY --from=build /out/sync-server /sync-server
# 配置文件模板(默认值;token 必须用环境变量 SYNC_TOKEN 提供)
COPY config.example.json /config.json

# 数据目录:SQLite 文件落这里,部署时挂载卷持久化
VOLUME /data
ENV SYNC_DB_PATH=/data/sync.db

EXPOSE 8080
ENTRYPOINT ["/sync-server"]
