# 治愈猫 · Godot 4.7 原型

送礼向轻养成电子宠物猫（偏写实萌宠 3D 占位）。第一版：一只猫、一个小房间、摸摸 / 喂食 / 逗逗，无死亡惩罚。

## 环境

- Godot **4.7.2**（本机路径示例：`/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64`）
- 渲染：`mobile`（面向 Android）
- 语言：GDScript，UI 简体中文

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

1. 进入温馨小房间，中间是占位猫（胶囊+球体）。
2. 点底部 **摸摸 / 喂食 / 逗逗**：
   - 摸摸：心情↑、亲密↑，旁白「呼噜～再摸摸」，猫轻微弹跳
   - 喂食：饥饿↓、心情↑，「喵，好吃！」
   - 逗逗：心情↑、亲密↑、略饿，「逗我！还要～」
3. 右上角柔和进度条：心情 / 饥饿 / 亲密（0–100）。
4. 时间流逝：饥饿缓慢上升、心情缓慢下降；不会死亡或失败结局。
5. 约 0.9s 互动冷却，避免连点刷爆反馈。

## 关键文件

| 路径 | 作用 |
|------|------|
| `project.godot` | 项目名「治愈猫」，主场景 `scenes/main.tscn`，Mobile 渲染 |
| `scenes/main.tscn` | 房间 + 占位猫 + 相机灯光 + UI |
| `scripts/pet_stats.gd` | mood / hunger / bond |
| `scripts/cat_controller.gd` | 摸喂逗、冷却、弹跳、旁白 |
| `scripts/main_ui.gd` | 按钮与进度条绑定 |
| `docs/superpowers/specs/2026-11-03-cute-cat-pet-design.md` | 设计规格 |
| `docs/superpowers/plans/2026-11-03-cute-cat-pet-prototype.md` | 实现计划 |

## Android 导出备注（尚未正式导出 APK）

本仓库**未**附带已签名 APK。若本机已有 4.7.2 导出模板：

- 模板目录示例：`/workspace/xt/godot_templates/4.7.2.stable/`
  - `android_debug.apk` / `android_release.apk` / `android_source.zip`
- 在编辑器：**编辑器 → 导出 → 添加 Android**，将导出模板指向上述目录（或 Editor Settings → Export → Android → Android Template）。
- 需安装 JDK + Android SDK；debug 可先打未签名调试包验证。
- 项目已设 `renderer/rendering_method="mobile"`，适合手机。

导出步骤概要：打开项目 → 项目 → 导出 → Android → 选择 debug 模板 → 导出项目。具体签名与商店上架留待后续。

## 验收清单（原型）

- [x] 打开主场景可见房间与占位猫
- [x] 三个中文按钮可点，数值按设计变化
- [x] 可见弹跳反馈 + 中文旁白
- [x] hunger/mood 随时间缓慢变化
- [x] Godot 4.7.2 无头加载无脚本错误
