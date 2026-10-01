# VLESS + REALITY 一键部署脚本

当前脚本版本：`v1.0.0`

适用于 Ubuntu/Debian VPS，一键部署：

- Xray-core
- VLESS
- REALITY
- XTLS Vision
- TCP/RAW 传输
- 自动生成 UUID、REALITY 密钥和 ShortID
- 自动生成可导入 v2rayN 的 `vless://` 链接
- 自动执行一次完整的本机端到端代理测试
- 部署失败时自动恢复原来的 Xray 配置

本方案不要求购买或解析自己的域名。默认 REALITY 目标站为 `gateway.icloud.com`。

> 重要：脚本会替换 `/usr/local/etc/xray/config.json`。如果服务器里已经运行其他 Xray 节点，请先备份，或者优先使用一台新的 VPS。

## 一、开始前需要准备什么

你需要准备：

1. 一台 Ubuntu 或 Debian VPS。
2. 服务器的公网 IP，例如 `203.0.113.10`。
3. SSH 登录用户名，通常是 `root`。
4. SSH 登录密码，或者服务商提供的 SSH 私钥。
5. Windows 电脑上的 PowerShell 或 Windows Terminal。
6. Windows 客户端 v2rayN。

先在云服务商控制台的安全组/防火墙中添加入站规则：

| 项目 | 填写内容 |
| --- | --- |
| 协议 | TCP |
| 端口 | 443 |
| 来源 | `0.0.0.0/0` |

如果你运行脚本时使用了其他端口，就放行那个端口。

## 二、最推荐的安装方法：从 GitHub 下载

GitHub 仓库发布完成后，把下面命令中的：

- `<GitHub用户名>` 换成实际 GitHub 用户名；
- `<服务器公网IP>` 换成 VPS 的公网 IP。

### 第 1 步：在 Windows 上登录服务器

打开 Windows PowerShell。此时命令行开头一般是：

```text
PS C:\Users\你的用户名>
```

执行：

```powershell
ssh root@<服务器公网IP>
```

例如：

```powershell
ssh root@203.0.113.10
```

第一次连接可能看到：

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

输入：

```text
yes
```

随后出现：

```text
root@203.0.113.10's password:
```

这时输入服务器的 SSH 密码并按回车。

**输入密码时屏幕不会显示星号，也不会显示任何字符，这是正常现象。**

登录成功后，命令行会变成类似：

```text
root@服务器名称:~#
```

从这里开始，后面的 Linux 命令都要在服务器终端中执行，不是在 Windows 的 `PS C:\...>` 后面执行。

> SSH 密码只用于登录服务器。不要把密码写进脚本，也不要把密码填到 UUID、ShortID 或客户端链接里。

### 第 2 步：在服务器上下载固定版本脚本

登录服务器后执行：

```bash
curl -fL --retry 3 -o /root/vless-reality-oneclick.sh \
  "https://raw.githubusercontent.com/<GitHub用户名>/vless-reality-oneclick/v1.0.0/vless-reality-oneclick.sh"
```

这里使用 `v1.0.0` 标签，而不是始终下载会变化的 `main` 分支，方便以后复现同一个版本。

### 第 3 步：赋予执行权限

```bash
chmod +x /root/vless-reality-oneclick.sh
```

一台服务器上的同一个脚本通常只需要执行一次 `chmod +x`。

### 第 4 步：运行脚本

```bash
bash /root/vless-reality-oneclick.sh --show-link
```

脚本会尝试自动检测服务器公网 IP，并显示类似：

```text
服务器公网 IP 或域名 [203.0.113.10]：
```

- 方括号中的 IP 正确：直接按回车。
- 方括号中的 IP 不正确：输入服务器真实公网 IP，再按回车。
- 这里填写的是服务器公网 IP，不是 SSH 密码，也不是电脑的局域网 IP。

如果服务器已经存在 Xray 配置，会显示覆盖警告，并要求输入：

```text
OVERWRITE
```

只有确定可以替换原有 Xray 配置时才输入。脚本会先备份原配置，部署失败时会尝试自动恢复。

### 第 5 步：等待自动测试完成

脚本依次执行：

1. 安装所需系统组件。
2. 使用 XTLS 官方安装程序安装或更新 Xray-core。
3. 生成新的 UUID、REALITY 私钥、公钥和 ShortID。
4. 写入并检查服务端配置。
5. 启动 Xray，确认端口正在监听。
6. 启动一个临时本机客户端，通过新节点访问 HTTPS 网站。
7. 测试成功后生成 v2rayN 客户端链接。

成功时会看到：

```text
部署成功。
```

以及一条以 `vless://` 开头的客户端链接。

### 第 6 步：导入 v2rayN

1. 打开 v2rayN。
2. 先使用 v2rayN 的更新功能更新 Xray-core。
3. 在服务器终端中复制完整的 `vless://` 链接。
4. 在 v2rayN 中选择“从剪贴板导入 URL”，或者使用相应的剪贴板导入功能。
5. 选中新节点，并将它设置为活动服务器。
6. 打开系统代理，再测试网页。

不要截图、公开或发送这条客户端链接。链接中包含可用于连接服务器的认证信息。

## 三、什么时候输入 IP 和密码

| 阶段 | 输入内容 | 在哪里输入 |
| --- | --- | --- |
| SSH 登录 | 服务器公网 IP | Windows PowerShell 的 `ssh root@IP` 命令中 |
| SSH 登录 | 服务器 SSH 密码 | 出现 `password:` 后输入；屏幕不会显示字符 |
| 脚本运行 | 服务器公网 IP | 出现“服务器公网 IP 或域名”提示时确认或输入 |
| Xray 配置 | UUID、密钥、ShortID | 不需要手动输入，脚本自动生成 |
| v2rayN | `vless://` 链接 | 从服务器复制，然后导入 v2rayN |

脚本不会保存你的 SSH 登录密码。

## 四、如果暂时无法访问 GitHub：从 Windows 上传

本地保存了脚本时，可以在 Windows PowerShell 中执行：

```powershell
scp "C:\你的脚本目录\vless-reality-oneclick.sh" root@<服务器公网IP>:/root/
```

PowerShell 随后会要求输入服务器 SSH 密码。上传完成后执行：

```powershell
ssh root@<服务器公网IP>
```

登录服务器后执行：

```bash
chmod +x /root/vless-reality-oneclick.sh
bash /root/vless-reality-oneclick.sh --show-link
```

## 五、常用运行方式

交互式运行，自动检测公网 IP：

```bash
bash /root/vless-reality-oneclick.sh --show-link
```

直接指定公网 IP：

```bash
bash /root/vless-reality-oneclick.sh \
  --server-ip 203.0.113.10 \
  --show-link
```

指定其他端口：

```bash
bash /root/vless-reality-oneclick.sh \
  --server-ip 203.0.113.10 \
  --port 8443 \
  --show-link
```

指定另一个 REALITY 目标站：

```bash
bash /root/vless-reality-oneclick.sh \
  --target example.com \
  --show-link
```

指定 Xray-core 版本：

```bash
bash /root/vless-reality-oneclick.sh \
  --xray-version v26.7.28 \
  --show-link
```

查看脚本版本：

```bash
bash /root/vless-reality-oneclick.sh --version
```

查看所有参数：

```bash
bash /root/vless-reality-oneclick.sh --help
```

## 六、脚本参数

| 参数 | 作用 | 默认值 |
| --- | --- | --- |
| `--server-ip IP或域名` | 写入客户端链接的服务器公网地址 | 自动检测并询问确认 |
| `--port 端口` | Xray 服务端监听端口 | `443` |
| `--target 域名` | REALITY 目标站和 SNI | `gateway.icloud.com` |
| `--xray-version 版本` | 指定 Xray-core 版本 | XTLS 官方稳定版 |
| `--yes` | 已有 Xray 配置时跳过 `OVERWRITE` 确认 | 不启用 |
| `--show-link` | 部署成功后在屏幕显示完整链接 | 不显示 |
| `--version` | 显示脚本版本 | — |
| `--help` | 显示帮助 | — |

全自动示例：

```bash
bash /root/vless-reality-oneclick.sh \
  --server-ip 203.0.113.10 \
  --port 443 \
  --yes \
  --show-link
```

## 七、部署后保存在哪里

| 文件 | 内容 |
| --- | --- |
| `/usr/local/etc/xray/config.json` | Xray 服务端配置 |
| `/root/vless-reality-client.txt` | v2rayN 可导入的 `vless://` 链接 |
| `/root/vless-reality-secrets.env` | UUID、私钥、公钥、ShortID 等备份 |
| `/usr/local/etc/xray/config.json.backup.时间` | 原有配置备份（仅覆盖旧配置时生成） |

这些文件包含敏感凭据，只应由服务器管理员保存。不要上传到 GitHub。

如果以后忘记复制客户端链接，可以登录服务器后执行：

```bash
cat /root/vless-reality-client.txt
```

## 八、检查运行状态

查看 Xray 是否运行：

```bash
systemctl is-active xray
```

正常结果应为：

```text
active
```

查看端口：

```bash
ss -lntp | grep ':443'
```

检查配置：

```bash
/usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
```

查看最近日志：

```bash
journalctl -u xray -n 50 --no-pager
```

## 九、常见问题

### 1. SSH 密码输入后看不见字符

这是 Linux/SSH 的正常安全设计。继续输入完整密码并按回车即可。

### 2. 提示连接超时或 443 不通

检查云服务商安全组是否放行 TCP 443，同时检查 VPS 自身防火墙。脚本只会在检测到 UFW 已启用时自动添加对应的 TCP 放行规则，不能代替云服务商安全组。

### 3. v2rayN 延迟显示 `-1`

先确认：

- v2rayN 的 Xray-core 已更新；
- 导入的是脚本最后生成的新链接；
- 服务器 IP、端口和安全组正确；
- 节点已经设置为活动服务器；
- 系统代理已经打开。

有些客户端的延迟测试本身可能失败，但实际网页仍可使用，应同时做真实网页测试。

### 4. REALITY 端到端自测失败

目标网站的 TLS 特征可能已经变化。可以更换目标站后重试：

```bash
bash /root/vless-reality-oneclick.sh \
  --target 另一个合适的HTTPS域名 \
  --show-link
```

脚本会在写入正式配置后进行完整协议测试；如果测试失败，会尝试恢复部署前的配置。

### 5. TCP 在当前网络环境中被干扰

本脚本部署的是 VLESS + REALITY + TCP/RAW。任何协议都无法保证在所有网络和地区长期可用。如果服务器 TCP 路径被针对性干扰，应准备不同服务器、不同网络路径或合法合规的备用连接方案。

## 十、版本与更新规则

本项目使用语义化版本：

- `v1.0.0`：正式版本标签，内容固定，适合部署。
- `main`：最新开发版本，内容可能发生变化。
- 修复兼容性问题时增加补丁版本，例如 `v1.0.1`。
- 增加兼容功能时增加次版本，例如 `v1.1.0`。
- 出现不兼容改动时增加主版本，例如 `v2.0.0`。

正式使用时建议下载带版本号的标签，不要直接执行来源不明或内容可变的一行脚本。

## 十一、安全说明

- 仓库中的安装脚本不包含固定 UUID、私钥、ShortID、服务器 IP 或 SSH 密码。
- 所有节点凭据都在每次部署时由服务器随机生成。
- 不要把 `/root/vless-reality-secrets.env` 或 `/root/vless-reality-client.txt` 上传到公开仓库。
- 不要公开 `vless://` 客户端链接。
- 执行前可以先查看脚本内容，再运行。
- 请遵守服务器所在地、使用所在地以及网络服务提供商的法律法规和服务条款。

## 十二、项目文件

```text
vless-reality-oneclick/
├── vless-reality-oneclick.sh
├── README.md
├── CHANGELOG.md
├── LICENSE
├── VERSION
├── SHA256SUMS
├── PUBLISHING.md
├── .github/workflows/ci.yml
└── .gitignore
```

仓库所有者发布新版本时，请按照 [PUBLISHING.md](PUBLISHING.md) 操作。


