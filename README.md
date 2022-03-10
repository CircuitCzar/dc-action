# 发布 Docker 容器

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
