# 可圈office

可圈office 是面向中文办公场景定制的 office 套件，当前仓库用于持续构建和验证 macOS 与 Windows 安装包。

## 下载安装包

安装包通过 GitHub Actions 手动生成：

1. 打开仓库的 **Actions** 页面。
2. 选择 **Build installers** workflow。
3. 点击 **Run workflow**。
4. 在 `target` 中选择：
   - `both`：同时生成 macOS 和 Windows 安装包
   - `macos`：只生成 macOS 安装包
   - `windows`：只生成 Windows 安装包
5. （可选）保持 `upload_logs: true`，构建失败时也会上传日志，便于排查。
6. 构建完成后，在 workflow run 的 **Artifacts** 中下载：
   - `kdoffice-macos-installers`：macOS 安装包（`.dmg` / `.pkg`，可能附带构建归档）
   - `kdoffice-windows-installers`：Windows 安装包（`.msi`，可能附带相关安装组件）
   - `kdoffice-macos-logs` / `kdoffice-windows-logs`：构建日志（当 `upload_logs=true` 时）

## 当前平台状态

| 平台 | GitHub 构建入口 | 产物 |
| --- | --- | --- |
| macOS | `Build installers` → `target: macos` | `.dmg` / `.pkg` |
| Windows | `Build installers` → `target: windows` | `.msi` |
| macOS + Windows | `Build installers` → `target: both` | 同时上传两组 artifacts |

当前 workflow 默认生成未签名安装包，适合内部测试和验证。正式发布前还需要接入 macOS Developer ID 与 Windows 代码签名证书。

## 本地开发说明

本仓库是 LibreOffice 风格的可圈office 构建树。常用命令见 `clavue.md`。
