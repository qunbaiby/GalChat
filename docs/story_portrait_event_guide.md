# 固定剧情立绘事件规范

适用范围：
- `assets/data/story/scripts/**/*.json`
- 固定剧情 AVG 演出

目标：
- 支持双立绘与多立绘
- 支持显式入场、退场、站位、表情与焦点控制
- 兼容旧写法，不改字段也能继续跑

## 基本规则

- `speaker` 负责对白显示给谁说
- `character` 负责当前对白或事件驱动哪一个立绘角色
- 如果不写 `character`，默认用 `speaker`
- `player` 只用于文本说话人显示，不建议给玩家上立绘
- 主角色建议统一使用 `char`

## 支持的事件

### `dialogue`

原有字段：

```json
{
  "type": "dialogue",
  "speaker": "luna",
  "content": "你好。"
}
```

新增可选字段：

```json
{
  "type": "dialogue",
  "speaker": "luna",
  "character": "char",
  "position": "right",
  "expression": "shy",
  "enter": false,
  "exit": false,
  "focus": true,
  "animation": "fade_in",
  "exit_animation": "fade_out",
  "display_name": "",
  "content": "你好。"
}
```

字段说明：
- `character`: 立绘角色 ID，可写 `char`、`jing`、`ya`、`shuo`
- `position`: 站位
- `expression`: 固定剧情表情 ID
- `enter`: 说这句前是否强制入场
- `exit`: 说完这句后是否退场
- `focus`: 是否强制高亮为当前焦点；不写时默认按当前说话者自动高亮
- `animation`: 入场动画
- `exit_animation`: 退场动画
- `display_name`: 覆盖对白框显示名

### `show_character`

```json
{
  "type": "show_character",
  "character": "jing",
  "position": "left",
  "expression": "serious",
  "animation": "slide_left",
  "focus": false
}
```

用途：
- 提前让角色入场
- 不占用对白
- 可单独切站位或表情

### `hide_character`

```json
{
  "type": "hide_character",
  "character": "jing",
  "animation": "fade_out"
}
```

用途：
- 让指定角色退场

## 站位字段

当前支持：

- `far_left`
- `left`
- `left_center`
- `center`
- `right_center`
- `right`
- `far_right`

建议约定：
- 双人对话：主配角常用 `left` / `right`
- 三人对话：常用 `left_center` / `center` / `right_center`
- 群像或旁观者：可用 `far_left` / `far_right`

## 表情字段

固定剧情的表情切换不走 AI 大模型瞬时分析，而是由编剧在剧情 JSON 中显式填写 `expression`。

当前项目内已存在的常用表情 ID：
- `calm`
- `shy`
- `worried`
- `serious`

说明：
- 主角色 Luna 的表情资源链更完整，切换效果会更明显
- 某些 NPC 目前如果只有头像或单张静态图，写了 `expression` 也可能看不出差异
- 后续只要补齐 NPC 的立绘/表情资源，这套字段会自动生效

## 动画字段

常用入场动画：
- `fade_in`
- `slide_left`
- `slide_right`
- `slide_top`
- `slide_bottom`
- `none`

常用退场动画：
- `fade_out`
- `slide_out_left`
- `slide_out_right`
- `slide_out_top`
- `slide_out_bottom`
- `none`

## 推荐写法

### 1. 开场预上场

```json
{
  "type": "show_character",
  "character": "char",
  "position": "right",
  "expression": "calm",
  "animation": "fade_in",
  "focus": false
}
```

### 2. 对白里切表情

```json
{
  "type": "dialogue",
  "speaker": "luna",
  "character": "char",
  "position": "right",
  "expression": "worried",
  "content": "我还是有点没底。"
}
```

### 3. 说完即退场

```json
{
  "type": "dialogue",
  "speaker": "jing",
  "character": "jing",
  "position": "left",
  "expression": "serious",
  "exit": true,
  "exit_animation": "fade_out",
  "content": "今天就先到这里。"
}
```

## 编写建议

- 固定剧情优先显式写 `position`
- 情绪明显变化的关键对白建议显式写 `expression`
- 需要提前埋伏角色时，用 `show_character`，不要硬塞空对白
- 旁白只负责叙述，不建议绑定 `character`
- 一段剧情里尽量保持站位稳定，只有转场或调度需要时再改
