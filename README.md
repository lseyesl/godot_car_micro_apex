# Micro Apex

横屏俯视 3D 单机赛车，包含 8 款可解锁赛车、12 个路线方向、36 场生涯赛事、性能升级、计时挑战和驾驶训练。

当前版本 **0.10.1 产品候选版**。完整玩法、验收范围及发行前事项见 [产品说明](docs/product.md)。

[查看新增地图、车辆与实机截图](docs/expansion.md)。

## 开始开发

使用 Godot **4.7 stable** 打开 `project.godot`，按 F5 运行。游戏运行不需要 Blender。

```sh
godot --headless --path . --editor --import
godot --editor --path .
```

云环境已准备的引擎在 `/workspace/.cloud-tools/bin/godot`；先将该目录加到 PATH，避免使用预装的旧版本。

## 游玩

先完成驾驶训练，再参加生涯，赢得星级和金币，解锁杯赛、车辆并升级性能。自由比赛和练习可以随时重玩已拥有车辆。

| 操作 | 手机 | 键盘 |
| --- | --- | --- |
| 转向 | 左下左右按钮 | A / D 或方向键 |
| 油门 | GAS | W / 上方向键 |
| 刹车 | BRAKE | S / 下方向键 / 空格 |
| 倒车 | 停稳后松开并再次按刹车 | 同左 |
| 复位 | 长按 RESET 1.2 秒 | 长按 R |
| 暂停 / 返回 | 暂停按钮 / 系统返回 | Esc |

设置中可调整自动油门、触控尺寸、镜头、画质、音乐和主音量。进度保存在 `user://micro_apex.cfg`，上一份有效备份为 `.bak`。单机游戏不收集或上传玩家数据。

## 验证与打包

```sh
python3 tools/validate.py --godot godot
# 包含四车、六路线、原厂与满级的 48 组自动驾驶检查：
python3 tools/validate.py --godot godot --balance
# 配置 SDK 36、Build Tools 36.0.0、Java 和 Godot 模板后：
bash tools/build_android.sh
```

`build/android/` 提供可安装的调试签名验收包和需要发行方签名的未签名发行包。请先完成真机验收，再进入商店发行流程。

## 工程结构

- `scripts/career.gd`：杯赛、奖励、解锁、购买与升级。
- `scripts/save_store.gd`：原子保存、回滚和备份恢复。
- `scripts/frontend.gd`：俱乐部、生涯、车库、自由驾驶、设置和许可页面。
- `scripts/main.gd`：比赛、教学、结算、镜头与音频流程。
- `scripts/vehicle_dynamics.gd`、`race_progress.gd`：车辆动力与合法计圈。
- `scripts/track_path.gd`、`track_view.gd`：正反路线与程序化场景。
- `tests/`：规则、整场比赛、生涯与升级回归检查。
- `tools/build_audio.py`：原创合成音效与音乐生成器。
- `assets/`：模型、Blender 源文件、字体与第三方许可。
