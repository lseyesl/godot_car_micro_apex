# 单片厚纸板树木（本地候选）

这些改动已纳入 0.13.15 `paper_craft` 发布源码；本页保留各阶段的本地验证记录。可安装包与实际发布状态以 [GitHub Releases](https://github.com/lseyesl/godot_car_micro_apex/releases) 和对应 Actions 为准，Android 真机仍未验收。

按用户要求，仅改造 `paper_craft` 的三种树。原有两款单片草丛保留；赛车、建筑、灌木、叶簇资产与其他非树模型不改，original / bright_clay 不变。没有推送、APK 构建、标签或发布操作。

## 实际造型与摆放

| 资源 | 造型 | 真实板厚 | 三角形：前 → 后 |
| --- | --- | --- | --- |
| `tree.glb` | 略不规则的宽叶树剪影 | 0.10 | 1410 → 116 |
| `district_oak.glb` | 宽圆橡树冠与直立树干 | 0.12 | 12272 → 116 |
| `district_pine.glb` | 三层锯齿松树剪影 | 0.12 | 11334 → 116 |

每棵树是一条 15 点连续外轮廓的封闭挤出实体。树干与树冠的正反面共享接边，颜色不同但属于同一连通网格；切边有三层纸芯和真实凹入接缝。没有交叉片、独立立体树冠或隐藏的旧网格。严格侧面只看到窄切边，是单片设计的预期。

保留原根节点、语义节点名称及枢轴变换；旧树冠节点变为空的 Node3D，以免留下旧体块。整体宽度和顶部高度按原模型实际顶点保持；底边改为模型根坐标 0。摆放时根节点下移到地面 -0.08，缩放后也不会浮起；花槽小松树则落在原花槽顶面 0.48。包围盒契约仅对三种纸模树明确调整，其余模型仍保持原契约。

树板固定面向游戏相机方位 35.54°，加确定性的 ±8°变化，不使用逐帧 billboard。保留原点位、树木数量、地标／赛道预留位置；原随机数仍按原次数消费，避免带动后续布局变化。不添加或更改碰撞、驾驶、插值、UI、声音、震动。

实际渲染发现两类树绕过了这三个 GLB：路边花槽的程序化小松树，以及 Riviera 的程序化棕榈树。因此纸模版也将这些入口切换到同一套厚板：花槽用缩小的 `district_pine`；原棕榈位置使用 `tree` 宽叶树剪影，**不保留原棕榈叶形**，没有增加第 38 个资源。未调用的 `club_tree` / `pine_tree` 树木入口也有同样的纸模分支。非树的花槽、蘑菇、仙人掌、灌木等保持原样。

纸模树不再挂两团立体叶簇；叶簇 GLB 本身未修改，其他风格继续按原方式挂载。当前 37 个纸模中，单片厚板是 3 种树加 2 种草丛，共 5 个；其余 32 个仍是立体纸板造型。

## 真实渲染前后对照

Godot 4.7 stable / Blender 4.3.2，Linux Mesa llvmpipe，1280×720。使用相同的参考模型包围盒固定相机，固定灯光；灰色地面属于预览场景，非树木新增底座。游戏近景来自实际放置点。不是概念图或 Android 真机截图。

| 视图 | 修改前 | 修改后 |
| --- | --- | --- |
| 宽叶树正面 | ![前](screenshots/tree-board-before-tree-front.png) | ![后](screenshots/tree-board-after-tree-front.png) |
| 宽叶树侧面 | ![前](screenshots/tree-board-before-tree-side.png) | ![后](screenshots/tree-board-after-tree-side.png) |
| 宽叶树斜侧 | ![前](screenshots/tree-board-before-tree-oblique.png) | ![后](screenshots/tree-board-after-tree-oblique.png) |
| 橡树正面 | ![前](screenshots/tree-board-before-district_oak-front.png) | ![后](screenshots/tree-board-after-district_oak-front.png) |
| 橡树侧面 | ![前](screenshots/tree-board-before-district_oak-side.png) | ![后](screenshots/tree-board-after-district_oak-side.png) |
| 橡树斜侧 | ![前](screenshots/tree-board-before-district_oak-oblique.png) | ![后](screenshots/tree-board-after-district_oak-oblique.png) |
| 松树正面 | ![前](screenshots/tree-board-before-district_pine-front.png) | ![后](screenshots/tree-board-after-district_pine-front.png) |
| 松树侧面 | ![前](screenshots/tree-board-before-district_pine-side.png) | ![后](screenshots/tree-board-after-district_pine-side.png) |
| 松树斜侧 | ![前](screenshots/tree-board-before-district_pine-oblique.png) | ![后](screenshots/tree-board-after-district_pine-oblique.png) |
| Riviera 游戏相机 | ![前](screenshots/tree-board-before-race-0.png) | ![后](screenshots/tree-board-after-race-0.png) |
| Woodland 游戏相机 | ![前](screenshots/tree-board-before-race-1.png) | ![后](screenshots/tree-board-after-race-1.png) |
| 橡树实际放置近景 | ![前](screenshots/tree-board-before-placed-0.png) | ![后](screenshots/tree-board-after-placed-0.png) |
| 松树实际放置近景 | ![前](screenshots/tree-board-before-placed-1.png) | ![后](screenshots/tree-board-after-placed-1.png) |

三风格前后共 78 张控制图保存在 `build/validation/tree-board/`；本页收录纸模 26 张。`tools/render_tree_board.gd -- after` 可重拍当前风格。截图保存在工作区／本地文档，不代表已交付聊天附件。

## 隔离与性能代理

三种树总计 25,016 → 348 个三角形（-98.6%），GLB 总大小 3,384,548 → 37,440 字节。230 个受保护资源文件哈希一致，包含原版、黏土、两款单片草丛及其他纸模；纸模 manifest 仅三种树条目改变。原版与黏土 26 张控制图逐像素一致。

固定相机的 Riviera 游戏视图：draw calls 787→720，绘制图元 534017→372537；Woodland：784→646、601685→249745。两个树木近景分别 491→433、509355→386579，以及 500→356、680777→213803。树木改成单板及取消附加立体叶簇降低这些代理计数；不能据此宣称 Android FPS、温升或功耗通过。

## 验证与边界

46 项 Python 检查通过，含最终 GLB 单连通／封闭边、116 面预算、真实厚度、共面正反面和零高度底边检查；已有 37 模型物理层压接缝检查仍保留。三风格模型契约均会检查这三个树资源；十赛道纸模布景专项 4,798 项检查通过，覆盖相机朝向、落地／花槽顶面、单个网格与无附加立体叶簇。

三套完整回归各 31 组全部正常退出，共 93 组通过，覆盖十赛道、操控／碰撞、插值、倒计时／震动、移动 UI 与产品流程。三风格导出各含 37 模型；12 组环境隔离、30 次赛道初始化通过，纸模导出包额外检查三种树均只有一个网格且场景中确有厚板树。PCK 大小 original 65,821,728、bright_clay 29,416,560、paper_craft 25,635,688 字节，不是 APK 大小。导出配置已恢复，可选长期 `--balance` 未运行。预览工具存在与修改前相同的退出 ObjectDB 清理警告，不将其算作 Android 运行验证。无 Android 真机，手机侧面可读性、实际性能与用户视觉验收未完成。未重试旧 Library 401／artifact 403；本轮不推送或发布。
