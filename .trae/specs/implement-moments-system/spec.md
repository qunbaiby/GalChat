# 朋友圈系统 (Moments System) Spec

## Why
为了增强玩家与游戏角色之间的代入感和日常互动体验，我们计划在手机界面中引入“朋友圈”功能。这将允许角色根据时间、剧情进展发布包含图片和文字的动态，并让玩家能够点赞和评论，甚至获得角色的AI自动回复，从而营造出更真实的虚拟社交体验。

## What Changes
- 在手机界面 (`mobile_interface.tscn`) 中新增“朋友圈”应用入口。
- 新增 `MomentsPanel` UI 及相关子组件，用于展示朋友圈动态列表（包含头像、昵称、正文、配图、点赞数、评论区等）。
- 新增 `MomentsManager` 数据管理类，用于持久化存储朋友圈帖子、点赞状态及评论数据。
- 扩展 `DeepSeekClient` 与 `PromptManager`，增加“生成朋友圈文本”、“生成朋友圈配图”以及“回复玩家评论”的AI接口逻辑。
- 在 `EventManager` 中集成 `post_moment` 事件，允许剧情或特定时间触发角色发朋友圈。

## Impact
- Affected specs: 角色互动系统、手机UI系统、AI文本/图片生成系统、事件库。
- Affected code:
  - `scenes/ui/mobile/mobile_interface.tscn` (新增入口)
  - `scripts/ui/mobile/mobile_interface.gd` (入口绑定)
  - `scripts/data/event_manager.gd` (新增事件)
  - `scripts/api/deepseek_client.gd` (新增API调用)
  - 新增 `scenes/ui/mobile/moments/` 相关场景及脚本
  - 新增 `scripts/data/moments_manager.gd`

## ADDED Requirements
### Requirement: 朋友圈基础界面与入口
系统必须在手机界面中提供朋友圈入口，并能打开类似微信朋友圈的信息流面板。

#### Scenario: 玩家查看朋友圈
- **WHEN** 玩家点击手机界面中的朋友圈按钮
- **THEN** 打开朋友圈面板，并按时间倒序展示已有的动态列表。

### Requirement: AI动态发布机制
系统必须能够通过事件调用，让AI角色基于当前剧情或时间生成图文并茂的朋友圈。

#### Scenario: 剧情触发发朋友圈
- **WHEN** `EventManager.execute_event("post_moment")` 被调用
- **THEN** 触发AI接口生成文案与提示词，生成配图后，在朋友圈列表中新增一条动态。

### Requirement: 互动机制 (点赞与评论)
系统必须允许玩家对动态进行点赞和评论，并且角色AI能对玩家的评论进行针对性回复。

#### Scenario: 玩家评论并获得回复
- **WHEN** 玩家在某条动态下输入评论并发送
- **THEN** 评论显示在动态下方，系统后台触发AI回复请求，AI回复完成后追加显示在评论区。