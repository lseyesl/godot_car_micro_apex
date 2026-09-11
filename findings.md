# 已查明事实

- 仓库远程为 lseyesl/godot_car_micro_apex，SSH 主机别名为 mygithub.com。
- 已有 4 款赛车、11 种地图模型；project.godot、游戏脚本和主场景现已实现。
- 本地 Godot 为 4.7.stable；官方 GitHub release API 已确认 4.7-stable 的 Linux x86_64 程序、导出模板与 SHA512-SUMS.txt 存在。
- 本地未安装 Godot 导出模板。用户明确改用 GitHub 上手动打包，不再为本地打包补齐环境。
- 新工作流使用预构建 Android 模板，不走 Gradle；Java 17、Android SDK 35、Build Tools 35.0.1。
- 最终规则测试通过 34 项，场景集成测试通过 13 项。
- 独立困难 AI 在 12 个车型/赛道组合全部完成三圈，路外帧占比为 0；等权归一化最佳圈时平均值差约 2.19%。不能替代真人平衡验证。
- 实际六车普通难度林间折线比赛 185.18 秒结束，所有车辆无复位；玩家完赛时 1 辆 AI 已完赛，其余处于第三圈。
- 实际 Godot 菜单和比赛截图保存于 docs/screenshots；检查中修正了 HUD 锚点、过亮光照、选车展示顺序与模型遮挡。
