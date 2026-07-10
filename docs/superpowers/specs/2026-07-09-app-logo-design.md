# MyTime App Logo 设计规范

## 1. 设计目标

为 MyTime 设计一套可在 Android、iOS 及应用内全平台使用的 App Logo，延续现有简洁现代的视觉语言，强化「时间记录」品牌识别。

## 2. 设计原则

- **简洁现代**：无多余装饰，聚焦核心符号
- **品牌一致**：复用 App 现有配色与界面元素
- **全平台适配**：一次设计，覆盖启动图标、应用内 Logo、宣传物料
- **可扩展**：主 Logo 以 1024×1024 PNG 保存，平台图标通过 `flutter_launcher_icons` 自动生成各密度版本

## 3. 方案概述

采用用户提供的品牌图标设计：深色圆角方形背景上，一个蓝紫粉渐变的不闭合圆环包裹白色时钟指针，右上方点缀进度小点；底部以「MyTime」品牌文字收尾。整体简洁现代，与 App 深色主题协调。

## 4. 视觉规范

### 4.1 画布与外形

- 源文件尺寸：1024 × 1024 px
- 外形：圆角方形（iOS 风格 squircle / 连续曲率圆角）
- 圆角半径：约 22%（约 225 px），与 iOS 现代 App Icon 规范一致
- 背景色：深色 `#1a1a2e`

### 4.2 核心图形

- 不闭合渐变圆环，从蓝色 `#6366F1` 过渡到紫色 `#8B5CF6` 再到粉色
- 圆环内部为白色时钟指针（时针 + 分针）
- 开口处右上方排列 4 个渐变小点，暗示时间进度

### 4.3 品牌文字

- 内容：`MyTime`
- 位置：图标底部居中
- 字体：现代无衬线
- 「My」为白色，「Time」为蓝紫渐变，与圆环色彩呼应

### 4.4 安全区

- 核心图形位于画布中央安全区内
- 为 Android 自适应图标预留足够边距，避免被裁切

## 5. 平台适配

| 平台/场景 | 输出规格 | 说明 |
|---|---|---|
| Android Adaptive Icon | 前景层（圆环+指针+小点）+ 背景层（`#1a1a2e`） | 支持动态形状蒙版 |
| iOS App Icon | 1024×1024 圆角方形（含背景与文字） | Apple 自动应用圆角 |
| 应用内/启动页 | PNG `assets/logo/logo.png` | 与启动图标视觉一致 |
| 小尺寸 favicon | 16×16 / 32×32 | 使用无文字纯图形版本 |

## 6. 色板

| 用途 | 色值 |
|---|---|
| 图标背景 | `#1a1a2e` |
| 主深色（背景/文字对比） | `#1a1a2e` |
| 渐变起点 | `#6366F1` |
| 渐变终点 | `#8B5CF6` |
| 文字「My」 | `#FFFFFF` |

## 7. 输出文件清单

- `assets/logo/logo.png` — 主 Logo 源文件（1024×1024，圆角方形，含背景与文字）
- `assets/logo/ic_launcher_foreground.png` — Android 自适应图标前景（中心图形）
- `assets/logo/ic_launcher_background.png` — Android 自适应图标背景（纯色 `#1a1a2e`）
- `assets/logo/icon_mark.png` — 无文字纯图形符号
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 下各尺寸 PNG
- `android/app/src/main/res/mipmap-*/` 下各密度 PNG

## 8. 实现注意事项

- 品牌 Logo 使用用户提供的 PNG 源文件；应用内小图标仍遵循「不使用 emoji，图标用 SVG 或自绘 CustomPainter」规范
- Android 自适应图标前景与背景需分离，前景禁止靠近边缘，避免被裁切
- iOS 图标无需预切圆角，Apple 会自动处理
- 若未来需要修改 Logo，替换 `assets/logo/logo.png` 后重新运行 `flutter pub run flutter_launcher_icons` 生成平台图标

## 9. 验收标准

- [ ] 源文件 PNG 在 1024×1024 下清晰无锯齿
- [ ] Android 自适应图标在各密度下显示完整
- [ ] iOS 图标在 App Store 和桌面上比例协调
- [ ] 应用内 PNG Logo 在深色 Splash 背景下清晰可识别
- [ ] 无文字纯图形符号版本在极小尺寸（16×16）下仍可辨认
