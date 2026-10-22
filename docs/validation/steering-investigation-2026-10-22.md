# 车辆相对转向排查（2026-10-22）

## 结论与范围

基线及远端 main 均为 `aa687b749a8ca38c5cae11f04db0b3ce8cad8d0b`。目前未能在这份源码上复现“车头朝下时左右反向”，不能将本次工作称为完成故障修复。本次仅补充回归测试，没有更改驾驶参数、转向逻辑、输入映射或发布产物。

仓库、上级目录未发现 AGENTS.md 或项目 `.agents/skills`。已读取 README、`docs/validation.md`、现有测试和 `.codex/config.toml`。环境预装引擎为 4.6.3；验证实际改用下载到 `/tmp/godot47/` 的官方 Godot **4.7.stable.official.5b4e0cb0f**，并隔离 XDG 配置/存档到 `/tmp/apex-*`。

## 控制语义与代码证据

- A/左方向键、D/右方向键、触摸箭头、鼠标箭头统一进入 `touch_controls.gd`，左为 -1、右为 +1，同时按左右为 0。油门、刹车使用独立状态，支持多指和键盘/触控组合。
- `main.gd` 在比赛中直接把 `controls.driving()` 送入 `RaceCar.tick()`，没有按镜头、世界朝向或车头上下反号。
- `vehicle_dynamics.gd` 的前向为 `(-sin(yaw), -cos(yaw))`；轨道二维位置映射到三维 X/Z；`RaceCar` 的 `rotation.y` 使用同一 yaw。八款 GLB 的前轴都在本地负 Z、后轴在正 Z，与模拟前向一致。
- 当前请求角速度为 `-steering * abs(longitudinal) / radius * STEERING_GAIN`。正 yaw 向车身左侧转，故左键增加 yaw、右键减小 yaw；转向语义始终相对车头。屏幕朝下时按右，车头会朝屏幕左侧偏转，这是车身自身右侧。
- 倒车采用同一街机语义：左右控制车头自身的左右，与真实车辆倒车时方向盘的轮胎语义不同。停稳时无速度不原地自转；前进中持续刹车只停车，松开再按刹车才倒车（最高 6 m/s）。已有规则测试覆盖这一状态机，新增场景测试覆盖朝下倒车转向。
- yaw 每步 wrap 到 [-π,π)，但车辆基底通过 sin/cos 计算，未对跨接缝的原始角度差直接做转向判断。

历史提交 `40f036e` 已将有符号 longitudinal 改为绝对值。旧公式会在倒车及向后漂移时反号；这是历史故障的确定根因，不能作为当前报告已复现的证据。临时恢复旧公式作负对照时，扩展测试当时的 7038 项中有 1250 项失败；恢复当前公式后全部通过。负对照后增加了低速/高速样本，最终为 8910 项。

另有一项可重复现象：均衡车先以 16 m/s 右转 1 秒，再按左键，最初 9 个 60 Hz tick（0.15 秒）仍沿旧方向旋转。这来自转向状态 `move_toward(..., dt*9)` 与 yaw_rate 指数响应。朝上、π、-π+0.001 的延迟都相同。它可能造成短暂“反打后仍旧转”的观感，但尚无用户录像证明其对应本次投诉，故保留原有手感。

## 验证

以下均为实际运行结果，而非仅检查公式：

| 检查 | 结果 |
| --- | --- |
| `tools/validate.py` 标准完整套件（修改前、加入新回归后各一轮） | 两轮全部通过；每轮含 3 场 expansion_flow 比赛 |
| 扩展 `tests/steering_direction.gd` | 8910 checks，0 failures |
| 新增 `tests/steering_input.gd` | 412 checks，0 failures |
| Python Android 签名/清单单元测试 | 13 tests，全部通过 |
| Xorg + Godot OpenGL 游戏，XTest 操作系统键盘事件 | 10 checks，0 failures |

动力学检查覆盖八车、沥青/土路/草地、0.2/3/16/40 m/s 前进、倒车、向后侧滑、13 个角度（含 ±π 两侧及超过接缝的初值），并比较旋转同一个完整驾驶场景后的前向和速度。20 秒场景包含持续绕圈、反打、油门、松油、刹车、松开再按刹车。每种朝向都持续跨过 yaw 接缝。

新增场景测试经 `Input.parse_input_event()` 和引擎事件分发，覆盖 A/D、左右方向键、触摸、模拟鼠标、独立油门手指、滑动换向、鼠标+键盘、键盘+触控反向抵消、释放和朝下倒车；在正常比赛 physics tick 中检查模型实际全局基底与动力学前向一致。12 个朝向包含 180°、±π 两侧和考虑镜头 35.54° 后的屏幕正下方。脚本模式 headless 默认窗口为 64×64，测试明确设置 1280×720，避免屏幕坐标缩放导致的测试伪失败。

图形检查使用 Xorg :88 和 Mesa llvmpipe。操作系统层通过 libXtst 发送 A/D+W，在 0、π、π-0.001、-π+0.001、镜头 yaw+π 五个朝向分别左右驾驶；完整游戏输入链和模型前向的侧向点积均正确。截图显示屏幕朝下时按右和 GAS。该检查是桌面图形验证，不能替代 Android 真机多点触控和真人手感验证。

本地支持证据位于 `build/validation/`（按仓库规则忽略）：`baseline-summary.log`、`final-summary.log`、`steering_direction.log`、`steering_input.log`、`steering-negative-control.log`、`steering-os-input.log`、`steering-os-screen-down.png`。临时图形验证脚本也保存在该目录。它们不属于发布产物。

复跑新增测试：

```sh
# 使用项目要求的 Godot 4.7，并给 XDG 配置/缓存/数据目录提供可写路径。
godot --headless --path . --editor --import
godot --headless --path . --script res://tests/steering_direction.gd
godot --headless --path . --script res://tests/steering_input.gd
python3 -m unittest discover -s tests -p 'test_*.py'
# 新增输入场景已接入标准入口：
python3 tools/validate.py --godot godot
```

## 尚缺的复现信息

需要出问题的安装包版本及 APK SHA-256/来源、能看清按钮点亮状态和车头的短录像，以及发生时是否倒车/漂移、自动油门设置。应先核对安装包是否含当前 main 的修复，再按录像中的输入顺序重放。现阶段没有依据新增按朝向反号的补丁，也没有依据把反打惯性直接删除。

未推送、未打标签、未发布或部署；没有合并旧历史。
