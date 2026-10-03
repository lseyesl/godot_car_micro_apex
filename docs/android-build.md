# 在 GitHub 手动构建 Android APK

工作流：`.github/workflows/android-debug.yml`。只配置 `workflow_dispatch`，提交代码和 PR 不会自动打包。

## 使用

1. 将工作流、`export_presets.cfg`、Godot 工程代码和运行所需资产提交到仓库。工作流须先存在于默认分支，GitHub 才会显示手动运行入口。
2. 打开 GitHub 仓库 → **Actions** → **Build Android APK** → **Run workflow**。
3. 选择需要构建的分支，填写必填的 **tag**（例如 `v0.9.0`），点击 **Run workflow**。这是将要创建的 Release 标签；代码仍来自所选分支的本次运行提交。
4. 成功后，在仓库 **Releases** 页面直接下载 APK，或点击运行摘要中的 Release 链接。另附 SHA-256 校验文件和包信息；该次运行的 **Artifacts** 也保留一份。

工程和游戏代码现已落地。工作流在打包前运行规则、操控、碰撞、生涯与完整产品流程测试；代码和资源需先提交并推送到所选分支。

## 配置

- Ubuntu 24.04，官方 Godot **4.7-stable** 和匹配的 Android 调试模板，下载后核对官方 SHA-512。
- Java 17，Android SDK 36 / Build Tools 36.0.0；使用预构建模板，不启用 Gradle。
- 导出预设名为 `Android`；应用 ID 为 `org.lseyesl.microapex`。
- `project.godot` 启用 `rendering/textures/vram_compression/import_etc2_astc`；Android 导出要求此项，即使使用 GL Compatibility 渲染器。工作流先导入资源，再导出 APK。
- 仅包含 **ARM64**，适合红米 K40；这是调试 APK，不是商店发布包。
- 不需要仓库密钥或发布签名。每次运行生成临时调试签名，因此不同运行的 APK 可能需要卸载旧版后安装；卸载会清除本地游戏记录。
- 每次手动构建成功后，使用输入的 `tag` 创建预发布 Release，绑定本次构建的提交。标签须以字母或数字开头，仅包含字母、数字、点、下划线或连字符，并符合 Git 标签格式；打包前检查标签不能已存在。发布成功后再次构建需填写新标签，保留旧包。调试版不会标记为 Latest。
- Release 附件长期保留，直到手动删除。Artifacts 中的 APK 保留 14 天，构建日志保留 7 天；不上传应用商店。
- Release 发布使用内置 `GITHUB_TOKEN` 的 `contents: write` 权限，无需额外配置 PAT。
- Godot 版本升级时，同时修改工作流中的 `GODOT_VERSION`、`GODOT_TEMPLATE_VERSION` 和编辑器设置文件名。
- 横屏、暂停恢复等运行行为由 Godot 工程代码配置，工作流不替代这些功能。

## 验证范围

本地检查工作流语法与导出预设，实际云端构建以 GitHub Actions 的执行结果为准。APK 安装及红米 K40 帧率仍需实机验证。

## 本地候选版构建

当前工程还提供 `tools/build_android.sh`，生成 ARM64 调试签名验收 APK 和未签名发行 APK。步骤、产物路径和真机验收边界见 [产品说明](product.md)。未签名发行 APK 需要发行方的正式签名；本地脚本不会创建或上传发行证书。
