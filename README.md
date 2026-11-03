# 治愈猫 · Godot 4.7 原型（v0.2.3）

送礼向轻养成电子宠物猫（Vuena 绑定可爱猫 + 骨骼动画）。轻养成 + 治愈日常：一只猫、温馨小房间、摸摸 / 喂食 / 逗逗，无死亡惩罚。

## 环境

- Godot **4.7.2**（本机路径示例：`/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64`）
- 渲染：`mobile`（面向 Android）
- 语言：GDScript，UI 简体中文
- **屏幕方向：自动旋转（sensor）** — 横竖屏都会适配 UI；基准分辨率 1280×720（竖屏 720×1280）

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

推荐安装 `cute-cat-pet-0.2.3-release.apk`。若已装旧 debug 包，请先卸载再装（签名不同）。

## 授权

猫模来自 Vuena / Popyca「Cute Pets」（CC0）。工程代码按仓库许可证使用。
