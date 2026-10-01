# 发布到 GitHub

下面的步骤供仓库所有者使用。普通安装用户不需要执行本文件中的命令。

## 1. 创建空仓库

在 GitHub 中创建一个公开仓库：

```text
vless-reality-oneclick
```

创建时不要自动添加 README、`.gitignore` 或 LICENSE，因为本项目已经包含这些文件。

## 2. 上传本地项目

在 Windows PowerShell 中进入本项目目录：

```powershell
cd "C:\Users\10129\Documents\ChatGPT\codex_practice\vless-reality-oneclick"
```

初始化 Git 并提交：

```powershell
git init -b main
git add .
git commit -m "Release v1.0.0"
```

把 `<GitHub用户名>` 替换为真实用户名，然后关联并推送：

```powershell
git remote add origin https://github.com/<GitHub用户名>/vless-reality-oneclick.git
git push -u origin main
```

GitHub 如果要求认证，请按照浏览器登录提示或 Personal Access Token 流程完成认证。不要在公开命令、README 或截图中写入 GitHub 密码、Token 或服务器密钥。

## 3. 创建固定版本标签

```powershell
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

标签推送后，固定版本下载地址为：

```text
https://raw.githubusercontent.com/<GitHub用户名>/vless-reality-oneclick/v1.0.0/vless-reality-oneclick.sh
```

## 4. 创建 GitHub Release

在仓库网页打开 `Releases`，选择 `Draft a new release`：

1. Tag 选择 `v1.0.0`。
2. Release title 填写 `v1.0.0`。
3. 发布说明复制 `CHANGELOG.md` 中对应版本的内容。
4. 可选：上传本地打包的 ZIP 文件。
5. 发布 Release。

## 5. 发布前检查

确认以下项目全部满足：

- `VERSION` 与脚本中的 `SCRIPT_VERSION` 一致。
- `CHANGELOG.md` 已增加当前版本记录。
- `README.md` 中的示例版本号已经更新。
- `bash -n vless-reality-oneclick.sh` 检查通过。
- `SHA256SUMS` 已按最终脚本重新生成。
- 仓库不包含真实 UUID、私钥、ShortID、服务器 IP 或客户端链接。
- GitHub Actions 检查通过后再发布 Release。

Linux 中更新校验值：

```bash
sha256sum vless-reality-oneclick.sh > SHA256SUMS
```

PowerShell 中可以查看校验值：

```powershell
Get-FileHash -Algorithm SHA256 .\vless-reality-oneclick.sh
```

