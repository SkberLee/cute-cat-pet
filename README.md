# 治愈猫 · Godot 4.7 原型（v0.2.9）

送礼向轻养成电子宠物猫。v0.2.7 起可玩的主场景改为 **2D 像素风**（星露谷式 16-bit 原画，资源在 `assets/pixel/`）；原先的 3D 房间与模型仍保留在仓库里（`scenes/main_3d.tscn`、`scripts/legacy_3d/`、`assets/models/`），不再作为启动场景。轻养成 + 治愈日常：一只猫、温馨小房间、摸摸 / 喂食 / 逗逗，无死亡惩罚。

## 环境

- Godot **4.7.2**（本机路径示例：`/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64`）
- 渲染：`mobile`（面向 Android）
- 语言：GDScript，UI 简体中文
- **屏幕方向：自动旋转（sensor）** — 横竖屏都会适配 UI；基准分辨率 1280×720（竖屏 720×1280）

## v0.2.9 新内容

- **重画侧面走路**：侧身不再把正面大眼睛和大脸贴在横着的身子上。头、鼻子朝着走路方向，一只侧脸眼睛，近耳清晰、远耳略靠后，四条腿有真正的步幅，肉垫在抬脚时可见。左右仍共用一张侧面图（向左水平翻转）。
- 同步更新了 `idle_side` / `sit_side`。正面和背面走路保持 v0.2.8。截图见 `screenshots/v029_walk_left.png`、`v029_walk_right.png`、`v029_walk_side_strip.png`。

## v0.2.8 新内容

- **猫咪四向走路**：补上朝屏幕（walk_down）、背对（walk_up）和更清楚的侧面走（walk_side，左右共用、向左时水平翻转）各 4 帧，以及对应的 idle / 背坐 `sit_up`。走路不再只靠侧面图左右翻转，上下走也不会再横着滑或停下突然正坐。
- 朝向由移动向量决定（主轴 + 约 1.15 倍滞回，斜向沿用最近的前后或左右）；正面和背面图绝不翻转。自由走动、走向食物、追玩具都走同一套朝向；停下时坐在对应方向的 idle。
- 像素预览见 `assets/pixel/preview_walk_dirs.png` 与 `screenshots/pixel_preview_cat_walk.png`；游戏内截图见 `screenshots/v028_walk_*.png`、`screenshots/v028_portrait_roam.png`。

## v0.2.7 新内容

- **全面换成 2D 像素**：用已提交的像素包（`assets/pixel/`，commit b1bd945）组装房间、猫咪 `AnimatedSprite2D`、食物/玩具、48px 抚摸手掌、九宫格 HUD/按钮/选择器和嘴边对话框。最近邻过滤。中文写在 Godot Label / Theme 上（按钮框是空的）。
- 玩法保持不变：摸摸、四种食物、四种玩具、换装主题、心情/饥饿/亲密（小心情）、自由走动、点猫放大、存档、无死亡惩罚、横竖屏、安卓优先。
- 3D 资源不删除，只是把主场景切到 2D。截图见 `screenshots/v027_*.png`。

## v0.2.6 新内容

- **只显示小手**：去掉手臂、袖子和袖口，手腕以柔和的圆形收尾；手掌朝下沿额头→后颈抚摸的动作不变，猫头仍随之微微下压。竖屏 / 横屏低机位 / 放大视角均已截图确认手不会被头挡住（`screenshots/v026_pet_hand_*`）。
- 清理了 `pet_hand.gd` 中不再使用的 2D 画手代码；`smoke_main` 的说话断言不再依赖固定台词池（原先会随机失败）。

## v0.2.5 新内容

- **精致的 3D 小手**：掌心、五指（带指节弧度和指甲）、拇指、柔和肤色、白袖口 + 粉色圆点袖子；手掌朝下，从猫头顶后侧伸入，沿额头→后颈轻轻来回抚摸并按压，猫头随之微微下压（`HeadLean` 骨骼修改器）。竖屏 / 横屏 / 放大视角均已截图验证（`screenshots/v025_pet_hand_*`）。
- **精致的玩具老鼠**：水滴形身体、圆耳朵（粉色内耳）、珠子眼睛、粉鼻子、胡须、卷曲尾巴、粉色小脚、毛毡缝线；追逐动作保持不变（`screenshots/v025_mouse_*`、`v025_toy_mouse_*`）。

## v0.2.4 新内容

- 猫脚：四只脚有趾缝和粉色肉垫（程序化网格，挂在脚骨骼上）。
- 摸摸：一只卡通小手在猫头顶来回抚摸，配爱心。
- 喂食：弹出食物选择（小鱼干 / 猫粮 / 罐头 / 牛奶），食物出现在猫面前，猫走过去低头吃，食物逐渐变少；不同食物台词和数值不同。
- 逗逗：弹出玩具选择（逗猫棒 / 毛线球 / 激光点 / 小老鼠），各自有不同的运动方式和猫的反应（扑、跳、追跑）。
- 新增 `smoke_interactions.gd`；横竖屏均可用。

## v0.2.3 新内容

- 竖屏：相机按横向 FOV 拉远，整只猫 + 大半个房间可见；UI 按方向缩放（竖屏 720x1280、横屏 1280x720），按钮变大 2x2 排布，状态卡更大。
- 猫在整个房间自由走动（绕开家具），朝向行进方向，到点后坐/发呆/跳/小睡；镜头跟随。
- 气泡每帧跟随下巴骨骼，尾巴指向嘴，限制在屏幕内；字更大。
- 修复触屏双击缩放（模拟鼠标事件去重）。

## v0.2.2 新内容

- 小猫说话改为**跟着猫嘴走的弹出对话框**（圆角气泡 + 小尾巴，3D→2D 锚定）
- 软弹出动画，几秒后自动收起；新台词会干净替换上一句
- 摸/喂/逗、自主玩耍、换装、里程碑、近距离查看等文案都走气泡

## v0.2.1 新内容

- 竖屏 HUD：2×2 按钮网格、更近的猫机位、统计卡不透明 + 描边阴影
- 横屏 HUD：统计卡更实、右侧留白，减少木桌透色
- 进度条底轨对比度加强
- 猫会在房间自主玩耍（坐着 / 换姿势 / 轻跳 / 短距离走）
- 点猫近距离查看，再点或「返回」退出
- 横竖屏均支持

## v0.2.0 内容

- 可爱猫头应用图标（launcher + adaptive）
- 横竖屏自适应 UI + 相机微调
- 亲密度里程碑（25/50/75/100）解锁甜句与心心装饰
- 软 BGM + 里程碑/换装音效
- 本地存档（心情/饥饿/亲密/房间主题）
- 房间换装（腮红粉 / 薄荷绿 / 天空蓝 / 日落暖，随亲密解锁）
- Debug + Release 签名 APK

## 打开与运行

```bash
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --editor
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_stats.gd
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_main.gd
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_save.gd
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_portrait_theme.gd
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_hud_zoom.gd
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_autonomy.gd
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_speech.gd
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_interactions.gd
```

## 怎么玩

1. 进入温馨小房间，中间是绑定猫（默认坐姿）。
2. 点 **摸摸 / 喂食 / 逗逗**：改心情、饥饿、亲密度，播骨骼动画与旁白。
3. 亲密涨到阈值后解锁更甜的话、心心装饰，以及 **换装** 房间主题。
4. 猫会自己玩耍；点猫可放大细看，点「返回」退出近景。
5. 关掉再开进度还在（`user://cute_cat_save.json`）。

## 关键文件

| 路径 | 说明 |
|------|------|
| `scenes/main.tscn` | 主场景（房间 + 猫 + UI） |
| `scripts/cat_controller.gd` | 互动、自主玩耍、音效 |
| `scripts/main_ui.gd` | 横竖屏 HUD、点猫放大 |
| `scripts/pet_stats.gd` | 数值与里程碑 |
| `scripts/room_cosmetics.gd` | 房间主题 |
| `scripts/save_manager.gd` | 本地存档 |
| `assets/models/cute_cat_rigged.glb` | Vuena CC0 绑定猫 |
| `docs/release-signing.md` | Release 签名说明 |

## 下载

GitHub Releases：https://github.com/SkberLee/cute-cat-pet/releases

推荐安装 `cute-cat-pet-0.2.9-release.apk`。若已装旧 debug 包，请先卸载再装（签名不同）。

## 授权

猫模来自 Vuena / Popyca「Cute Pets」（CC0）。工程代码按仓库许可证使用。
