# 治愈猫 · Godot 4.7 原型（v0.1.0）

送礼向轻养成电子宠物猫（Vuena 绑定可爱猫 + 骨骼动画）。第一版：一只猫、温馨小房间、摸摸 / 喂食 / 逗逗，无死亡惩罚。

## 环境

- Godot **4.7.2**（本机路径示例：`/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64`）
- 渲染：`mobile`（面向 Android）
- 语言：GDScript，UI 简体中文
- **屏幕方向：横屏（landscape）** — 1280×720 基准，按钮与房间构图按横屏打磨；竖屏也能扩边，但推荐横握

## 打开与运行

```bash
# 编辑器打开
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --editor

# 直接运行主场景
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet

# 无头冒烟（数值）
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_stats.gd

# 无头冒烟（主场景互动）
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless -s res://scripts/smoke_main.gd
```

也可在 Godot 项目管理器中「导入」本目录后按 F5。

## 怎么玩

1. 进入温馨小房间（木地板、窗光、小家具），中间是绑定猫（默认坐姿）。
2. 点底部 **摸摸 / 喂食 / 逗逗**（大触控按钮）：
   - 摸摸：心情↑、亲密↑，旁白随机甜句，猫播 `call`，轻音效
   - 喂食：饥饿↓、心情↑，播 `eat`
   - 逗逗：心情↑、亲密↑、略饿，播 `jump`
3. 右上角「小心情」卡片：心情 / 饥饿 / 亲密柔和进度条。
4. 时间流逝：饥饿缓慢上升、心情缓慢下降；不会死亡或失败结局。
5. 互动冷却约 0.7–1.35s，冷却时按钮禁用。

## 关键文件

| 路径 | 作用 |
|------|------|
| `project.godot` | 项目名「治愈猫」v0.1.0，主场景，Mobile + 横屏 |
| `scenes/main.tscn` | 温馨房间 + 绑定猫 + 灯光 + 手机 UI |
| `assets/models/cute_cat_rigged.glb` | Vuena 绑定猫（LOD0，骨骼动画） |
| `assets/sfx/*.wav` | 摸摸/喂食/逗逗轻音效（程序生成） |
| `scripts/pet_stats.gd` | mood / hunger / bond |
| `scripts/cat_controller.gd` | 摸喂逗、冷却、骨骼动画、旁白、音效 |
| `scripts/main_ui.gd` | 大按钮、柔和进度条、冷却禁用 |
| `export_presets.cfg` | Android arm64-v8a 导出预设 |
| `build/治愈猫-0.1.0-debug.apk` | Debug APK（若已导出；默认 gitignore） |
| `docs/superpowers/specs/2026-11-03-cute-cat-pet-design.md` | 设计规格 |
| `docs/superpowers/plans/2026-11-03-cute-cat-pet-prototype.md` | 实现计划 |

## 3D 猫模型

- **来源**：[Vuena Cute Pets FREE Sample](https://vuena.itch.io/blocky-pets-free)（Popyca / designer-toy cat）
- **许可**：CC0 1.0（详见 `assets/models/CAT_LICENSE.txt`；署名非必须）
- **游戏内**：`cute_cat_rigged.glb`（albedo 1024²，仅 LOD0；约 **7,188** 三角）
- **骨骼动画映射**：idle→`sit`，摸摸→`call`，喂食→`eat`，逗逗→`jump`
- 旧 `tabby_cat_mobile.glb` 仍留作对照。

## Android 导出（v0.1.0）

```bash
source /workspace/xt/env.sh   # JAVA_HOME + Android SDK
mkdir -p build
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=/workspace/xt/keys/debug.keystore
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless \
  --export-debug Android /workspace/cute-cat-pet/build/治愈猫-0.1.0-debug.apk
```

- 包名：`com.skberlee.cutecatpet`
- 架构：arm64-v8a
- 模板：`~/.local/share/godot/export_templates/4.7.2.stable/`（指向 `/workspace/xt/godot_templates/4.7.2.stable/`）
- Debug 签名：本机 `/workspace/xt/keys/debug.keystore`（经环境变量注入，不写入仓库）

## 验收清单（0.1.0）

- [x] 温馨房间（窗光、家具道具）
- [x] 绑定猫 sit/call/eat/jump + 中文甜句旁白 + 轻音效
- [x] 横屏手机 UI：安全边距、大按钮、柔和进度条
- [x] Godot 4.7.2 无头冒烟通过
- [ ] Debug APK 可安装（见 `build/`）
