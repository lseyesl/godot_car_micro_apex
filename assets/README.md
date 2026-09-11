# 美术资产 v2

参考图由内置 imagegen 生成，完整提示词保存在 `references/prompts.json`。四张车型多视图和一张地图元素参考板保存在 `references/`。

模型由 Blender Python 根据参考图建模，是可编辑的三维几何，不是自动图像转三维重建。v2 重做了车身截面、座舱、开口轮拱、辐条轮毂、刹车盘、分片车窗、灯组与前后进气结构；土路车包含胎块、护板和挡泥板。

## 文件

- `blender/micro_apex_assets.blend`：可编辑资产总库，参考图打包在文件内。
- `models/*.glb`：四款赛车和十一种地图模块，分别导出。
- `models/manifest.json`：各资产三角形数量与参考图对应关系。
- `previews/cars.png`、`previews/map_kit.png`：实际 Blender 模型渲染预览。
- `previews/car_*-v2.png`：四款赛车的实际模型近景，用于与参考图检查形体和部件。
- `../tools/build_assets.py`：可重建资产的脚本。重复执行会覆盖本目录中同名生成文件。

## 接入约定

- 单位为米。Blender Z 向上、+Y 为车头；GLB 导出后 Godot Y 向上、-Z 为车头。
- 车辆根节点位于地面中心，四个 `Wheel_*` 枢轴节点单独保留；每车合并为车身与四个车轮共 5 个网格，轮毂、胎块和刹车盘随对应车轮节点运动。
- 道路宽 6 米，直道长 10 米，道路顶面高度为 0；弯道为中心半径 9 米的四分之一圆，内外半径分别为 6 米与 12 米。接缝需按端点与切线方向对齐。
- 资产使用不透明基础色材质；玻璃为不透明深色材质，适合俯视镜头。
- 模型不含驾驶物理、碰撞体或路面触发器。这些需在 Godot 中另外设置；不同车型能力也不能由外观自动推导。
- 这些模型已通过原资源路径接入游戏。赛车每款约 7,400–17,000 三角形，具体数量见清单；增加细节后的红米 K40 性能仍需实测。

## 重建

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_assets.py
```
