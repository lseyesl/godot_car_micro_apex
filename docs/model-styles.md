# 模型与 UI 风格

默认是 `original`，另有 `bright_clay` 手捏黏土 A 和 `paper_craft` 折纸纸模 C。三套均对应同一组 37 个模型、同一布景和玩法，不提供游戏内切换。`bright_clay` 保留旧选择值兼容，但已替换最初仅改材质的美术方案；新的几何与 UI、真实 Godot 样板见 [A/C 改造](crafted-styles.md)。

| 选择值 | 模型 | UI |
| --- | --- | --- |
| `original` | 原始 GLB，保持不动 | 原有深色主题 |
| `bright_clay` | 圆润不规则几何、压痕法线、哑光颜料 | 厚实捏塑边缘、压印箭头、按压层次 |
| `paper_craft` | 折面、纸边厚度、折线和纸纤维 | 叠纸卡片、折角按钮、裁切箭头 |

## 开发与构建

```sh
godot --path .                              # 默认 original
MICRO_APEX_MODEL_STYLE=bright_clay godot --path .
MICRO_APEX_MODEL_STYLE=paper_craft godot --path .
```

环境变量仅对未锁定的桌面编辑器开发配置生效。非法值明确报错退出，启动后选择固定；Android 不读取设备环境变量。

Actions **Build Android APK** 的 `model_style` 为上述三个明确选项，默认 `original`。输入赋给 `MICRO_APEX_MODEL_STYLE`，由 `prepare_model_style.py --from-environment` 验证，固化为 `config/model_style.json` 的 `locked=true` 和模型清单。**CI 环境不会自动继承进 APK**，已安装游戏从包内配置识别风格。

```sh
bash tools/build_android.sh                 # 忽略开发者同名环境变量，固定 original
bash tools/build_android.sh bright_clay
bash tools/build_android.sh paper_craft
```

本地脚本退出时恢复开发配置与导出预设。三套资源清单必须同步；缺失、非法选择或 partial manifest 在修改配置前停止。原始 GLB 在 `assets/models/`，工艺资源在 `assets/styles/<style>/models/`。每包只带所选资源；工艺包还过滤原版表面纹理，其余两套模型/风格纹理均不打包。

不要把环境变量读取改成设备 shell 依赖，也不要把开发者本机环境隐式用作默认构建选择。不要覆盖原始资产或既有 Release/tag。

## 验证

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/validate.py --godot godot
MICRO_APEX_MODEL_STYLE=bright_clay python3 tools/validate.py --godot godot
MICRO_APEX_MODEL_STYLE=paper_craft python3 tools/validate.py --godot godot
python3 tools/verify_model_style_exports.py --godot godot
```

最后一项仅本地导出三份 Android 资源 PCK，不构建 APK、不调用远端。它验证每包全部模型可加载、其余风格资源不存在、相反/非法环境变量不改变选择，以及三套各六赛道的场景和 UI 初始化。完成后恢复源配置。

Android APK 检查器 `--expected-model-style` 验证锁定配置、全部导入模型目标及资源排他。新 artifact/Release 带 `model-style.json`，发布器要求与 APK 中配置一致；历史不含风格配置的四文件 artifact 保持兼容，新包不得省略元数据。风格名进入 APK 文件名和发布标题，独立风格须使用独立新标签。

三种风格仍使用同包名和固定调试签名，只能覆盖切换，不能并存；发布需正常递增版本码。附件只允许 GitHub Actions runner 上传，不允许云端直接上传，见 [Android 构建发布流程](android-build.md)。本轮仅本地实现与验证，未获准推送或发布，Android 真机外观与性能仍待验收。
