# 治愈猫 · Godot 4.7 原型（v0.2.0）

送礼向轻养成电子宠物猫（Vuena 绑定可爱猫 + 骨骼动画）。轻养成 + 治愈日常：一只猫、温馨小房间、摸摸 / 喂食 / 逗逗，无死亡惩罚。

## 环境

- Godot **4.7.2**（本机路径示例：`/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64`）
- 渲染：`mobile`（面向 Android）
- 语言：GDScript，UI 简体中文
- **屏幕方向：自动旋转（sensor）** — 横竖屏都会适配 UI；基准分辨率 1280×720

## v0.2.0 新内容

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
```

## 怎么玩

1. 进入温馨小房间，中间是绑定猫（默认坐姿）。
2. 点 **摸摸 / 喂食 / 逗逗**：改心情、饥饿、亲密度，播骨骼动画与旁白。
3. 亲密涨到阈值后解锁更甜的话、心心装饰，以及 **换装** 房间主题。
4. 关掉再开进度还在（`user://cute_cat_save.json`）。

## 关键文件

| 路径 | 作用 |
|------|------|
| `assets/icons/` | 应用图标与 Android launcher |
| `assets/sfx/` | 互动音效 + 软 BGM |
| `scripts/pet_stats.gd` | 数值 + 里程碑 |
| `scripts/save_manager.gd` | 本地存档 |
| `scripts/room_cosmetics.gd` | 房间主题 |
| `scripts/cat_controller.gd` | 互动 / 动画 / BGM |
| `scripts/main_ui.gd` | 横竖屏 UI |
| `docs/release-signing.md` | Release 签名说明 |
| `export_presets.cfg` | Android arm64 导出 |

## 3D 猫模型

- 来源：[Vuena Cute Pets FREE Sample](https://vuena.itch.io/blocky-pets-free)（CC0）
- 动画：idle→`sit`，摸摸→`call`，喂食→`eat`，逗逗→`jump`

## Android 导出（v0.2.0）

```bash
source /workspace/xt/env.sh
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=/workspace/xt/keys/debug.keystore
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless \
  --export-debug Android /workspace/cute-cat-pet/build/cute-cat-pet-0.2.0-debug.apk
```

Release 见 `docs/release-signing.md`。

- 包名：`com.skberlee.cutecatpet`
- 架构：arm64-v8a
