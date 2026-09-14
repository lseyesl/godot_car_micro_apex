# 进度

- 用户确认完整设计并要求开始代码实现；随后要求优先编写手动 GitHub Actions 打包流程。
- 创建 .github/workflows/android-debug.yml、export_presets.cfg、.gitignore 和 docs/android-build.md。
- 工作流仅 workflow_dispatch，包含工程预检查、官方下载校验、导入、ARM64 调试导出、签名验证和 artifact 上传。
- Ruby YAML 解析通过，确认只有手动触发；actionlint 1.7.12 无错误，导出配置检查通过。
- 尚未推送仓库、触发云端构建或生成 APK。

## 游戏代码实现

- 新建 project.godot、主场景、车型目录、路径采样、车辆物理、顺序检查点、AI、三维赛道、赛车模型接入、多点触控、存档、小地图和主界面。
- 生成基础引擎、路面和碰撞 WAV 音效，源码模型/参考图目录添加 .gdignore，避免构建时要求 Blender。
- 正在修复首次导入的脚本类型推断错误；下一步为规则测试和完整 AI 自动试跑。

## 实现完成与验证

- 已修复导入问题、HUD 锚点、光照、起跑线附近排名与菜单模型顺序。
- 规则测试：34 项，0 失败。场景测试：13 项，0 失败。包括真实节点暂停、恢复倒数、系统中断、多指输入、复位和结算。
- 12 组独立三圈试跑全部完成，初始归一化圈时差 2.19%；完整六车场景 185.18 秒完赛。
- GitHub 手动工作流增加打包前规则与场景测试，actionlint 通过。
- README.md、docs/android-build.md、docs/validation.md 提供运行、构建和验收说明；报告及截图已保存。
- 尚未提交/推送、手动触发 GitHub APK 构建，也未进行红米 K40 实机验证。
- headless 模式跳过音频播放，避免无音频后端的退出资源警告；图形模式保留全部音效。最终场景清理回归通过。

## 美术返工开始

- 上一版已提交并推送为 eec0be5。
- 用户指出模型与参考图差距过大；开始对四款车和地图元素重建几何，并保留现有游戏节点接口与尺寸约定。

## 美术 v2 返工与验证

- 重建四款车和十一种地图资产，保留原 GLB 路径；新增车身截面、轮拱、辐条轮组、分片玻璃、进气结构与土路胎块。修正座舱衔接、灯组贴合及卡钳随车轮旋转问题。
- Blender 完整导出 15 项资产并保存可编辑源文件，四款近景、车辆总览和地图总览已渲染复核。
- 四车均保留 4 个 Wheel 枢轴、5 个网格；Godot 导入无脚本/资源错误，场景集成检查 13 项、0 失败。
- 更新 docs/screenshots/menu.png 与 gameplay.png；比赛视角车体较小，近景细节主要在选车界面呈现。
- 普通车型 7,356–7,360 三角形，土路车 16,888；材质和参考图仍有差距，未进行手机性能验收。此次返工尚未提交或推送。

## 2026-09-12 驾驶视野与弯道调整

- 比赛视野 64 → 44，前视时间 0.55 → 0.32 秒。四车低速半径降至 5.8/3.6/4.8/4.4 米，保持高速抓地力限制。
- 三赛道增加 S 弯、折返段与回头弯；新圈速单独存储，旧纪录保留。
- 39 项规则、13 项场景检查通过；12 组独立 AI 三圈全部完成且路外帧占比为 0。新版数据见 docs/validation/balance-corners-v2.json。
- 六车同场普通难度测试通过：玩家 AI 218.52 秒完成三圈，全部车辆复位次数为 0；结算时未完赛车按进度排名。数据见 docs/validation/race-soak-corners-v2.json。

## 转向过度操控 v3

- 进一步缩小转弯半径并加倍方向响应；高速车身旋转与行进方向分离，土路增加甩尾，支持反打。
- 操控专项 36 项、规则 39 项、场景 13 项通过；12 组 AI 三圈试跑全部完成，专项检查接入手动 Android 工作流。
- v3 六车同场测试通过：玩家 AI 218.60 秒完成三圈，六车均无复位；未完赛车在结算时按进度排名。报告见 docs/validation/race-soak-oversteer-v3.json。

### 2026-09-12 — Square-field routes and bridges
- Rebuilt all three tracks as interior crossing layouts inside a 500 m square.
- Added height-aware roads, ramps, bridge decks/rails/supports, vehicle height and pitch, and route continuity for AI and ranking.
- Added checkpoint height validation, square minimaps with bridge layering, and a fresh lap-record namespace.
- Validated rules (39), integration (13), all three solo AI laps and a six-car three-lap race with no resets.
- Added reproducible square-layout tests and a three-map overview capture.

### 2026-09-14 — Raised curbs and wall friction
- Added continuous 0.85 m red/white curbs with convex collision along both sides of all tracks, including ramps and bridges.
- Head-on boundary collisions stop cars; scraping projects and reduces velocity once per tick.
- Verified all 69 physical curb tests and 39 rule checks; captured the in-game curb appearance.
- Six-car race regression passed: three player laps in 255.75 s, zero resets across all cars.
