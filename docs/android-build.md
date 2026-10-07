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
- Java 17，Android SDK 36 / Build Tools 36.0.0；使用匹配的 `android_source.zip` 模板，通过 Gradle 合并清单并打包。
- 导出预设名为 `Android`；应用 ID 为 `org.lseyesl.microapex`。
- `project.godot` 启用 `rendering/textures/vram_compression/import_etc2_astc`；Android 导出要求此项，即使使用 GL Compatibility 渲染器。工作流先导入资源，再导出 APK。
- 仅包含 **ARM64**，适合红米 K40；这是调试 APK，不是商店发布包。
- CI 从 `ANDROID_DEBUG_KEYSTORE_BASE64` 仓库 Secret 恢复固定调试密钥，不再每次生成。恢复密钥和最终 APK 都必须匹配 `config/android-debug-cert.sha256` 中的证书 SHA-256；缺少或误配密钥会停止构建。
- 每次手动构建成功后，使用输入的 `tag` 创建预发布 Release，绑定本次构建的提交。标签须以字母或数字开头，仅包含字母、数字、点、下划线或连字符，并符合 Git 标签格式；打包前检查标签不能已存在。发布成功后再次构建需填写新标签，保留旧包。调试版不会标记为 Latest。
- Release 附件长期保留，直到手动删除。Artifacts 中的 APK 保留 14 天，构建日志保留 7 天；不上传应用商店。
- Release 发布使用内置 `GITHUB_TOKEN` 的 `contents: write` 权限，无需额外配置 PAT。
- Godot 版本升级时，同时修改工作流中的 `GODOT_VERSION`、`GODOT_TEMPLATE_VERSION` 和编辑器设置文件名。
- 横屏、暂停恢复等运行行为由 Godot 工程代码配置，工作流不替代这些功能。

## 验证范围

本地检查工作流语法与导出预设，实际云端构建以 GitHub Actions 的执行结果为准。APK 安装及红米 K40 帧率仍需实机验证。

## 本地候选版构建

当前工程还提供 `tools/build_android.sh`，生成 ARM64 调试签名验收 APK 和未签名发行 APK。步骤、产物路径和真机验收边界见 [产品说明](product.md)。未签名发行 APK 需要发行方的正式签名；本地脚本不会创建或上传发行证书。

## 0.10.1：Android 清单导出修复

排查 v0.1.3 Release 的 `package info null` 反馈时，Actions 本身成功，APK 的 ZIP、校验和与签名也正常，但清单中发现两个 Provider 共用了 `org.lseyesl.microapex.fileprovider`。Godot 4.7 的非 Gradle 导出会统一改写 Provider authorities；改用 Gradle 清单合并后，FileProvider 和 AndroidX Startup 保留各自独立的 authority。

这修复了已验证的清单缺陷，尚不能代替反馈设备上的安装复测，也不能仅凭该发现认定所有 `package info null` 都是同一原因。

CI 现在安装匹配的 Android 源模板，导出时使用 `--install-android-build-template`。完整 JDK 17+ 必须包含 `javac`。生成的 `android/build/` 不提交到 Git。

新增检查：

```sh
python3 -m unittest discover -s tests -p test_android_manifest.py
python3 tools/verify_android_apk.py path/to/app.apk --sdk "$ANDROID_HOME"
```

检查覆盖 ZIP 完整性、ARM64 库、APK 签名、16 KB 对齐，以及重复 Provider authority、启动入口和 activity-alias 目标。旧 APK 被重复 authority 检查拒绝；检查通过的 APK 仍需要目标 Android 设备验证。

## 固定调试签名的一次性配置

旧流程每次在全新 Runner 上调用 `keytool -genkeypair`，即使别名和密码相同，也会生成不同私钥。旧 Action 没有保存私钥，APK 只包含公钥证书，无法从 APK 还原旧私钥。除非另有旧密钥备份，否则固定签名的新系列不能覆盖旧的临时签名版本。不要直接卸载需要保留进度的旧应用，先安排数据迁移。

本次固定使用已有的本地测试密钥 `build/android/debug.keystore`。它与既有本地测试包同属一个签名系列，与旧 GitHub Action 的临时签名系列不同。

1. 妥善备份现有 keystore；不提交、不上传至 Release 或普通 Artifact。
2. 仓库 **Settings → Secrets and variables → Actions → New repository secret**。
3. Name 填 `ANDROID_DEBUG_KEYSTORE_BASE64`，Secret 填已有 keystore 的完整 Base64。当前工作区已准备 `build/android/ANDROID_DEBUG_KEYSTORE_BASE64.txt`，该文件被 Git 忽略，权限为 0600。它包含私钥材料，仅用于 Secrets 安全输入，勿贴到 issue、聊天或构建日志。
4. 保存 Secret 后，提交并推送本次工作流修复，再使用新标签运行 Action。
5. 后续包保持应用 ID 和签名不变，并递增 Android `version/code`，才能覆盖升级。不要删除或替换该 Secret。固定调试密钥不作为商店正式发布密钥。

若使用有 Secrets 写权限的本地 GitHub CLI，也可安全地从文件上传（不会在命令行参数中展开私钥）：

```sh
gh secret set ANDROID_DEBUG_KEYSTORE_BASE64 --repo lseyesl/godot_car_micro_apex < build/android/ANDROID_DEBUG_KEYSTORE_BASE64.txt
```

当前云环境的 GitHub 集成能推送代码和执行 Action，但访问 Secrets 列表及公钥接口返回 HTTP 403，因此未能自动设置 Secret；这与 Git 推送权限是两回事。

校验及产物：

```sh
python3 -m unittest discover -s tests -p 'test_android_*.py'
python3 tools/prepare_android_signing.py --check-existing
python3 tools/verify_android_apk.py path/to/app.apk --sdk "$ANDROID_HOME" --certificate-sha256-file config/android-debug-cert.sha256
```

Release 附 `signing-certificate.sha256`（公开证书指纹，不含私钥），便于比较两次构建的签名。与 APK 文件 SHA-256 区分：APK 内容和版本变化时文件摘要应当变化，而签名证书指纹应保持一致。
