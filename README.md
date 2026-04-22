# Alpine 一键安装脚本（Reality + Hysteria2）

用于在 Alpine 系统快速安装 Xray Reality / Hysteria2，安装文件均从官方仓库拉取。

---

## 🚀 快速使用

```bash
apk update
apk add curl bash wget
```

```bash
wget https://github.com/sumeping/alpine_reali/blob/main/xray.sh
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

---

## ⚙️ 其他脚本

### 调整 TCP 窗口大小

```bash
bash <(curl -L -s https://github.com/sumeping/alpine_reali/blob/main/tcp_alpine.sh)
```
