# 治愈猫 · 像素资源包（起步包）

这是治愈猫 2D 像素版（v0.2.7 起）使用的原创像素素材。

风格参考了《星露谷物语》那种温暖、好认的 16-bit 小品（有限暖色盘、清晰外轮廓、两到三档明暗），但全部是重新绘制的，**没有描摹、拆解或使用任何星露谷或其他商业游戏的精灵图**。

每个 `.aseprite` 源文件包含两层：

- `原图`：当前 3D 游戏截图缩小后的半透明参考层（方便对照外形与配色）
- `pixel`：真正的像素画

导出给游戏用时请**只导出 `pixel` 层**（隐藏 `原图`）。可用 LibreSprite / Aseprite：

```bash
libresprite -b --layer pixel cat/sit.aseprite --save-as cat/sit.png
```

仓库里已经附带了对应的 PNG（硬边缘、透明底、无抗锯齿，适合 nearest-neighbor 放大）。预览总图见 `preview_sheet.png`，四向走路见 `preview_walk_dirs.png`，放大展示图在仓库根目录的 `screenshots/pixel_preview_*.png`。

## 尺寸约定

| 类型 | 尺寸 | 说明 |
| --- | --- | --- |
| 猫咪角色 | 64×64 | 每帧一张；脚底大致对齐 y=61 |
| 食物 / 玩具 / 小图标 | 32×32 | 透明底 |
| 抚摸小手 | 32×32 与 48×48 | 只有手掌，手腕圆润收尾，没有手臂和袖子 |
| 爱心 / 闪光 / 对话框尾巴 | 16×16 | |
| 对话框 9-slice | 32×32 | 四角约 8px，可拉伸中心 |
| 地板 / 墙壁 | 32×32，另有 16×16 地板 | 地板是横向木纹无缝拼贴 |
| 地毯 | 80×48 | 白色圆/六边意向 |
| 灯 | 32×48 | 薄荷绿色圆灯 |
| 心情面板 | 96×48 | 仅框和三条示意进度，不含汉字（游戏里再叠字） |
| 按钮 | 48×20 | 普通 / 按下 |
| 选择面板 | 128×48 | 四个圆形槽 |
| 应用图标 | 64×64 源图，以及 192×192（3 倍邻近放大） | 黄橘虎斑猫头；另有透明前景 `icon_app_fg` |

## 文件夹

```
assets/pixel/
  originals/     3D 游戏截图原图（对照用，随仓库提交）
  cat/           坐、眨眼、侧坐、背坐；四向走路 walk_down / walk_up / walk_side（各 4 帧）；吃、跳/扑、睡、开心、打招呼；以及 idle_down / idle_up / idle_side
  room/          地板、墙、踢脚线、地毯、灯、纸箱、坐垫
  food/          小鱼干、猫粮碗（满/空）、罐头、牛奶碟（满/空）
  toys/          逗猫棒、毛线球、激光点、毛毡小老鼠
  fx/            小手、爱心、闪光、对话框
  ui/            面板、按钮、选择器、食物/玩具图标、应用图标
  palette.png    调色板色块
  palette.aseprite
  preview_sheet.png
  tools/         生成与打包脚本
```

动画类文件（`walk_down` / `walk_up` / `walk_side` / `eat` / `jump` / `sparkle`）的 `.aseprite` 里含多帧；同时导出了 `name_0.png`、`name_1.png`… 侧向左右共用 `walk_side`，游戏里对左走做水平翻转，正面和背面绝不翻转。

## 调色板（主色）

完整色块见 `palette.png`。常用颜色：

- 轮廓 `#6E402E`
- 毛色 `#FFD44A`、暗部 `#ECA830`、条纹 `#DC8C28`
- 白毛/袜子 `#FFFAF2`
- 眼睛青绿 `#2EB894`、瞳孔 `#12584A`
- 腮红/肉垫 `#FF9AAA` / `#E0768C`
- 木地板 `#F5E2B8`、墙 `#FFF6E6`
- 薄荷绿 `#A8D8B0`、毛线紫 `#A484D8`、小鱼蓝 `#60BADC`
- UI 边 `#E0AAAA`、心情粉 `#F080A0`、饥饿橙 `#F0B050`、亲密紫 `#A090D8`

## 命名

- 英文文件名 + 下划线，全部小写。
- 源文件与 PNG 同名：`cat/sit.aseprite` ↔ `cat/sit.png`。
- 图层名：`原图`、`pixel`。

## 重新生成

本机已安装 LibreSprite 1.3（命令 `aseprite` / `libresprite`，读取写入 `.aseprite`）。不要用付费 Aseprite 的安装包去替换它。

```bash
python3 assets/pixel/tools/gen_pixel.py
# 用 LibreSprite 正式重新保存所有 .aseprite：
find assets/pixel -name '*.aseprite' -print0 | while IFS= read -r -d '' f; do
  aseprite -b "$f" --script assets/pixel/tools/finalize.js --save-as "$f"
done
python3 assets/pixel/tools/compose_preview.py
```

`gen_pixel.py` 会用有限色盘、整数像素把画绘制进图层，并写入 `.aseprite`（含半透明 `原图` 层）。`finalize.js` 再交给 LibreSprite 官方编码器保存一遍。

## 许可

像素画为项目原创，按与本仓库相同的方式使用即可（可视作 CC0 素材起点）。`originals/` 里是本游戏自己的 3D 截图与图标，仅作对照，不是第三方商用素材。
