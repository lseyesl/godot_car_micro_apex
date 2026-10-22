# 在 GitHub 手动构建 Android APK

工作流：`.github/workflows/android-debug.yml`。只配置 `workflow_dispatch`，提交代码和 PR 不会自动打包。

## 使用

1. 将工作流、`export_presets.cfg`、Godot 工程代码和运行所需资产提交到仓库。工作流须先存在于默认分支，GitHub 才会显示手动运行入口。
2. 打开 GitHub 仓库 → **Actions** → **Build Android APK** → **Run workflow**。
3. 选择需要构建的分支。普通构建保持 **publish_release** 关闭，直接运行；只有同时构建和发布时才打开它并填写未使用的 **tag**。代码来自所选分支的本次运行提交。
4. 成功后从该 run 的 **Artifacts** 下载 APK、摘要和包信息。若打开了发布开关，也可从 **Releases** 下载。已有成功构建需要补发 Release 时，使用下方的只发布流程，不重新构建。

工程和游戏代码现已落地。工作流在打包前运行规则、操控、碰撞、生涯与完整产品流程测试；代码和资源需先提交并推送到所选分支。

## 配置

- Ubuntu 24.04，官方 Godot **4.7-stable** 和匹配的 Android 调试模板，下载后核对官方 SHA-512。
- Java 17，Android SDK 36 / Build Tools 36.0.0；使用匹配的 `android_source.zip` 模板，通过 Gradle 合并清单并打包。
- 导出预设名为 `Android`；应用 ID 为 `org.lseyesl.microapex`。
- `project.godot` 启用 `rendering/textures/vram_compression/import_etc2_astc`；Android 导出要求此项，即使使用 GL Compatibility 渲染器。工作流先导入资源，再导出 APK。
- 仅包含 **ARM64**，适合红米 K40；这是调试 APK，不是商店发布包。
- CI 从 `ANDROID_DEBUG_KEYSTORE_BASE64` 仓库 Secret 恢复固定调试密钥，不再每次生成。恢复密钥和最终 APK 都必须匹配 `config/android-debug-cert.sha256` 中的证书 SHA-256；缺少或误配密钥会停止构建。
- 仅打开 `publish_release` 时，构建成功后才使用输入的 `tag` 创建预发布 Release，绑定本次构建的提交。标签须以字母或数字开头，仅包含字母、数字、点、下划线或连字符，并符合 Git 标签格式；打包前检查标签不能已存在。发布成功后再次构建需填写新标签，保留旧包。调试版不会标记为 Latest。
- Release 附件长期保留，直到手动删除。Artifacts 中的 APK 保留 14 天，构建日志保留 7 天；不上传应用商店。
- Release 发布使用内置 `GITHUB_TOKEN` 的 `contents: write` 权限，无需额外配置 PAT。
- Godot 版本升级时，同时修改工作流中的 `GODOT_VERSION`、`GODOT_TEMPLATE_VERSION` 和编辑器设置文件名。
- 横屏、暂停恢复等运行行为由 Godot 工程代码配置，工作流不替代这些功能。

## 发布已有成功构建（不重建 APK）

**本项目 APK/Release 附件必须由 GitHub Actions runner 上传。** 云端 Codex 只负责获授权的推送、触发和查询，不直接调用 `uploads.github.com` 上传附件。云端 API 可创建 Release 草稿，但这不代表上传端点的认证也可用；遇到 401 不要反复云端直传，也不要为了发布重做已成功的构建。

使用 **Publish existing Android APK**（`.github/workflows/publish-android-artifact.yml`）。输入原成功 run ID、其 APK artifact ID、现有 debug prerelease 草稿 ID、标签、原构建完整 SHA 和已核验的 APK SHA-256。只有该发布 job 使用最小权限 `actions: read`（读取已有产物）和 `contents: write`（上传附件、发布及创建对应标签）；workflow 顶层权限为空。使用内置 `GITHUB_TOKEN`，不新增 PAT、签名密钥或仓库/组织安全设置。

本次转向修复示例（只首次触发一次；先查看有无同一草稿的在途发布）：

```sh
gh workflow run publish-android-artifact.yml --ref main \
  -f source_run_id=39740333461 \
  -f source_artifact_id=12409083126 \
  -f release_id=420423782 \
  -f tag=v0.13.3-steering-fix \
  -f build_sha=dde762193f346e99dc3a927dc0968f339a8af313 \
  -f apk_sha256=665176aa9473c6bf3ba88deb823c89067ff9ea9ab831e0ba21c2b0ea1b5c9072
```

发布流程核对原 run 已成功、APK 签名/清单/对齐验证步骤已成功、artifact 未过期且属于同一 run/SHA，再校验下载的 APK ZIP、ARM64 库、批准的 SHA-256、摘要文件、固定证书指纹和包版本。证书与版本基准从**原构建提交**读取，不使用发布 workflow 的新提交代替。原构建已执行密码学签名验证，发布阶段用批准的 APK 摘要确认字节相同。

附件上传后核对 GitHub 返回的每个附件大小及 SHA-256 digest，齐全后才公开草稿；保持 debug prerelease、非 Latest。标签必须指向 `build_sha`，不是新增 workflow/文档提交。应用内版本来自 APK；例如本包仍为 0.13.3/code 22，用 `v0.13.3-steering-fix` 区分修复，不覆盖旧 `v0.13.3`。发布说明应记录原 build 链接、SHA、调试性质及真机尚未验收。

失败恢复：先检查发布 run、原草稿和附件状态。复用同一 artifact/草稿；脚本对已上传且摘要/大小正确的附件跳过上传，不使用 `--clobber`。不完整、未知或冲突的附件会停止，先调查，不能自动覆盖旧附件或移动旧标签。已公开且完整匹配的同一发布可验证后直接返回。只有确认不存在仍在运行的相同发布后才恢复；artifact 过期时报告并安排新的受授权构建，而不是宣称复用了旧产物。

发布检查与工程入口见根目录 [AGENTS.md](../AGENTS.md)。这些是操作流程说明，不新增自定义审批规则。

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
