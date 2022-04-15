# 发布 Docker 容器

> 项目命名方式 App_v[0-9]

- [x] 发布 docker 镜像
- [x] 嵌入 Dockerfile 和 nginx 配置
- [x] 根据 App 个数动态生成 Dockerfile 和 nginx 配置

## 使用

```yaml
name: Publish Docker
on:
  push:
    branches:
      - "development"
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@master
      - name: Publish to Registry
        uses: zhoubin-datareachable/dc-action@main
        with:
          name: datareachable/dr_Front_qeditordashboard
          username: ${{ github.actor }}
          password: ${{ secrets.FRONT_CI_SECRETS }}
          registry: ghcr.io
          tags: "latest"
```

