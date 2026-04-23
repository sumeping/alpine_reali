# Alpine 一键安装脚本（Reality + Hysteria2）

用于在 Alpine 系统快速安装 Xray Reality / Hysteria2，安装文件均从官方仓库拉取。

项目引入参考：
https://github.com/lanzimiaomiao/miaosh/tree/main?tab=readme-ov-file#miaosh

---

## 🚀 快速使用

```bash
apk update
apk add curl bash wget
```

```bash
wget https://raw.githubusercontent.com/sumeping/alpine_reali/main/xray.sh
sh xray.sh
```

---

## ✨ 本次修改与优化

### 1) 新增端口交互输入（核心）

- 运行脚本时会提示输入监听端口
- 直接回车则默认使用 `443`
- 非法输入会提示重输（仅允许 `1-65535`）

已覆盖脚本：

- `xray.sh`
- `install_xray.sh`
- `install_hy2.sh`

### 2) 配置与输出端口保持一致

- 服务监听端口、分享链接、Clash/Surge 节点输出均改为动态端口
- 避免“配置是一个端口，输出还是 443”的不一致问题

### 3) Xray 内部端口冲突处理

- 当用户把主监听端口设为 `4431` 时
- 脚本会自动将内部 `dokodemo-door` 端口切换到 `4432`
- 避免端口占用冲突导致启动失败

### 4) 新增节点运行模式选择（避免一口气全开）

- 执行 `sh xray.sh` 时，新增交互菜单：
  - `1) Reality (VLESS)`（默认）
  - `2) Hysteria2`
  - `3) Reality + Hysteria2`
- 脚本会按选择生成配置，不再默认同时运行所有节点
- 安装完成后仅输出所选节点信息，并按所选类型写入历史链接记录

### 5) 增强帮助与历史查看

- 新增帮助命令：`sh xray.sh help`（或 `-h` / `--help`）
- 新增历史查看命令：`sh xray.sh links`（`history` 为别名）
- 卸载时会同步删除历史节点链接记录

---

## ⚙️ 其他脚本

### 调整 TCP 窗口大小

```bash
bash <(curl -L -s https://raw.githubusercontent.com/sumeping/alpine_reali/main/tcp_alpine.sh)
```
