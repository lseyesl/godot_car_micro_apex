# Micro Apex

Godot 4.7 制作的横屏俯视角 3D 赛车原型。四款赛车、三条混合路面赛道，提供六车场地竞速和无 AI 的计时练习。

## 启动

使用 Godot **4.7** 导入根目录的 `project.godot`，按 F6/F5 运行主场景。也可以在工程目录运行：

```sh
godot --editor --path .
godot --path .
```

运行时不需要 Blender。可编辑 Blender 源文件和 imagegen 参考图单独保留在 `assets/`，通过 `.gdignore` 排除在 Godot 导入之外。

## 操作

| 操作 | 手机 | 电脑开发 |
| --- | --- | --- |
| 转向 | 左下左右按钮，相对车头 | A / D 或左右方向键 |
| 油门 | 右下 GAS | W / 上方向键 |
| 刹车 | 右下 BRAKE | S / 下方向键 / 空格 |
| 倒车 | 停稳后松开刹车，再按住 | 同上 |
| 复位 | 长按 RESET 1.2 秒 | 长按 R |
| 暂停 | 右上暂停按钮 | Esc |

可以同时转向和加速/刹车。高速转向受抓地力限制；土路更容易滑动，路外会明显减速。绿色标杆指示下一合法检查点。漏点需返回或复位，不能靠抄近路计圈。

竞速固定 3 圈，玩家完赛立即结算。计时练习无圈数上限，通过“结束练习”退出。每款车、每条赛道分别保存最佳有效单圈；复位圈不刷新纪录。设置与纪录保存在 `user://micro_apex.cfg`。

## Android

使用 [手动 GitHub Actions 构建](docs/android-build.md)，下载 ARM64 调试 APK。不会在 push 或 PR 时自动触发。

## 验证

```sh
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/integration.gd
mkdir -p build
godot --headless --path . --script res://tests/benchmark.gd
godot --headless --path . --script res://tests/race_soak.gd
```

规则和场景集成测试已加入打包工作流。注意 Godot 某些脚本解析错误可能仍以退出码 0 返回，因此 CI 同时检查测试完成标记。

[验证报告](docs/validation.md)记录圈时、实际六车试跑、验证范围及未验证部分。当前完成的是可运行原型；云端 APK 构建与红米 K40 的安装、触控手感和帧率尚待验证。

## 主要代码

- `scripts/vehicle_dynamics.gd`：加速、刹车、倒车、转弯和路面差异。
- `scripts/track_path.gd` / `track_view.gd`：三条赛道的数据与三维场景。
- `scripts/race_progress.gd`：顺序检查点、有效圈、完赛和排名进度。
- `scripts/ai_driver.gd`：根据路线曲率、路面与难度制动，不改车辆属性。
- `scripts/main.gd`：选车、比赛状态、HUD、暂停和结算。
- `scripts/touch_controls.gd` / `save_store.gd`：多点触控与本地存档。
