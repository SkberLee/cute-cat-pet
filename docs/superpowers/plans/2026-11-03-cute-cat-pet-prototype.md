# 电子宠物猫原型 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Godot 4.7.2 做出可在安卓向导出的 3D 养猫原型：小房间、占位猫、摸/喂/逗与三项软数值。

**Architecture:** 单主场景挂房间、猫、UI 与 Stats 自动加载逻辑；`PetStats` 管数值与时间流逝；`CatController` 响应互动并驱动占位反馈；`MainUI` 绑定三按钮与状态条。

**Tech Stack:** Godot 4.7.2 · GDScript · 3D Mobile 渲染倾向 · 占位 Mesh/CSG（可换 glTF）

## Global Constraints

- 引擎版本：Godot 4.7.2.stable
- 项目根：`/workspace/cute-cat-pet`
- 语言：UI 文案简体中文
- 第一版仅猫；无死亡、无惩罚结局
- 数值范围 0.0–100.0：mood、hunger、bond
- 规格来源：`docs/superpowers/specs/2026-11-03-cute-cat-pet-design.md`

---

### Task 1: 初始化 Godot 项目

**Files:**
- Create: `project.godot`
- Create: `icon.svg`（可用默认）
- Create: `scenes/.gdkeep`、`scripts/.gdkeep`、`assets/.gdkeep`

**Interfaces:**
- Produces: 可被 Godot 4.7.2 打开的空项目，`application/config/name="治愈猫"`，主场景稍后设为 `res://scenes/main.tscn`；渲染器 `mobile`（Android）

- [ ] **Step 1: 用 Godot 命令行创建项目**

Run:
```bash
mkdir -p /workspace/cute-cat-pet/scenes /workspace/cute-cat-pet/scripts /workspace/cute-cat-pet/assets
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless --quit-after 1 2>/dev/null || true
```

若尚无 `project.godot`，手写最小配置：

```ini
; project.godot
config_version=5

[application]
config/name="治愈猫"
config/description="送礼向轻养成电子宠物猫原型"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "Mobile")

[rendering]
renderer/rendering_method="mobile"
```

- [ ] **Step 2: 验证可无头模式启动**

Run:
```bash
/workspace/xt/bin/Godot_v4.7.2-stable_linux.x86_64 --path /workspace/cute-cat-pet --headless --quit-after 1
```
Expected: 退出码 0，无 script error

- [ ] **Step 3: Commit**

```bash
cd /workspace/cute-cat-pet && git init && git add project.godot docs scenes scripts assets && git commit -m "chore: init 治愈猫 Godot 4.7 project"
```

---

### Task 2: PetStats 数值逻辑

**Files:**
- Create: `scripts/pet_stats.gd`
- Create: `scripts/tests/test_pet_stats.gd`（可选：用简单断言脚本在 `--script` 下跑；若无测试框架则用 main 内临时自检后删除）

**Interfaces:**
- Produces:
  - class_name `PetStats`
  - `var mood: float`、`var hunger: float`、`var bond: float`（0–100）
  - `func pet() -> void`、`func feed() -> void`、`func play() -> void`
  - `func tick(delta: float) -> void`：hunger 每秒 +0.4，mood 每秒 -0.15，clamp
  - 信号 `stats_changed`

- [ ] **Step 1: 实现 pet_stats.gd**

```gdscript
# scripts/pet_stats.gd
class_name PetStats
extends Node

signal stats_changed

@export var mood: float = 70.0
@export var hunger: float = 30.0
@export var bond: float = 10.0

const HUNGER_PER_SEC := 0.4
const MOOD_DECAY_PER_SEC := 0.15

func _clamp_all() -> void:
	mood = clampf(mood, 0.0, 100.0)
	hunger = clampf(hunger, 0.0, 100.0)
	bond = clampf(bond, 0.0, 100.0)

func pet() -> void:
	mood += 8.0
	bond += 3.0
	_clamp_all()
	stats_changed.emit()

func feed() -> void:
	hunger -= 25.0
	mood += 4.0
	_clamp_all()
	stats_changed.emit()

func play() -> void:
	mood += 10.0
	bond += 5.0
	hunger += 5.0
	_clamp_all()
	stats_changed.emit()

func tick(delta: float) -> void:
	hunger += HUNGER_PER_SEC * delta
	mood -= MOOD_DECAY_PER_SEC * delta
	_clamp_all()
	stats_changed.emit()
```

- [ ] **Step 2: 无头冒烟（打印初始与 pet 后）**

用临时 `scripts/smoke_stats.gd`：
```gdscript
extends SceneTree
func _init():
	var s = load("res://scripts/pet_stats.gd").new()
	s.pet()
	assert(s.mood > 70.0)
	print("smoke_stats ok mood=", s.mood)
	quit()
```
Run: Godot `--path ... --headless -s res://scripts/smoke_stats.gd`  
Expected: 打印 ok

- [ ] **Step 3: Commit**

```bash
git add scripts/pet_stats.gd && git commit -m "feat: add PetStats mood/hunger/bond"
```

---

### Task 3: 主场景房间 + 占位猫 + 控制器

**Files:**
- Create: `scripts/cat_controller.gd`
- Create: `scenes/main.tscn`（可用 Godot 生成或手写 TSCN）
- Modify: `project.godot` 确认 main_scene

**Interfaces:**
- Consumes: `PetStats.pet/feed/play/tick`
- Produces: `CatController` 方法 `do_pet()`、`do_feed()`、`do_play()`；短冷却；子节点 `MeshInstance3D` 或 CSG 占位猫缩放弹跳反馈

- [ ] **Step 1: 写 cat_controller.gd**（持有 PetStats 引用或同级节点路径 `%PetStats`）

```gdscript
# scripts/cat_controller.gd
extends Node3D

@onready var stats: PetStats = %PetStats
@onready var body: Node3D = %CatBody
@onready var feedback_label: Label = %FeedbackLabel

var _cooldown := 0.0
const COOLDOWN := 0.9

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	stats.tick(delta)

func do_pet() -> void:
	if _cooldown > 0.0: return
	_cooldown = COOLDOWN
	stats.pet()
	_bounce()
	_say("呼噜～再摸摸")

func do_feed() -> void:
	if _cooldown > 0.0: return
	_cooldown = COOLDOWN
	stats.feed()
	_bounce()
	_say("喵，好吃！")

func do_play() -> void:
	if _cooldown > 0.0: return
	_cooldown = COOLDOWN
	stats.play()
	_bounce()
	_say("逗我！还要～")

func _say(t: String) -> void:
	if feedback_label:
		feedback_label.text = t

func _bounce() -> void:
	if body == null: return
	var tw = create_tween()
	tw.tween_property(body, "scale", Vector3(1.15, 0.9, 1.15), 0.08)
	tw.tween_property(body, "scale", Vector3.ONE, 0.12)
```

- [ ] **Step 2: 搭建 main.tscn**

结构：
- `Main` (Node3D) +脚本可选
  - `WorldEnvironment`、`DirectionalLight3D`、`Camera3D`
  - `Room`：地板 CSGBox + 墙
  - `Cat` (Node3D, cat_controller.gd)
    - `CatBody` (%CatBody)：Capsule/Sphere Mesh 占位
    - `PetStats` (%PetStats)
  - `CanvasLayer/UI`：三按钮 + ProgressBar×3 + FeedbackLabel (%FeedbackLabel)

- [ ] **Step 3: 无头加载主场景**

Run Godot headless quit-after 2 with main scene  
Expected: 无 error

- [ ] **Step 4: Commit**

```bash
git commit -am "feat: main scene with placeholder cat and interactions"
```

---

### Task 4: MainUI 绑定

**Files:**
- Create: `scripts/main_ui.gd`
- Modify: `scenes/main.tscn`

**Interfaces:**
- Consumes: CatController `do_pet/do_feed/do_play`；PetStats `stats_changed`、mood/hunger/bond
- Produces: 按钮「摸摸」「喂食」「逗逗」；三条进度；反馈文案

- [ ] **Step 1: 实现 main_ui.gd 并连接信号**
- [ ] **Step 2: 手动或截图式验收清单写入 README**
- [ ] **Step 3: Commit** `feat: soft UI for pet/feed/play`

---

### Task 5: README + 安卓导出备注

**Files:**
- Create: `README.md`

内容：如何用 Godot 4.7.2 打开、如何玩、Android 导出后续步骤（模板路径若在 `/workspace/xt/godot_templates`）。

- [ ] **Step 1: 写 README**
- [ ] **Step 2: 最终 headless 冒烟**
- [ ] **Step 3: Commit** `docs: README for 治愈猫 prototype`

---

## 验收对照规格

| 规格项 | 任务 |
|--------|------|
| 三数值与自然变化 | Task 2 |
| 摸喂逗 | Task 3–4 |
| 房间+占位猫 | Task 3 |
| 无死亡 | Task 2 无失败态 |
| Godot 4.7 可开 | Task 1、5 |
