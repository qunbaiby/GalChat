# Tasks
- [x] Task 1: 盘点现有微聊入口与面板结构
  - [x] SubTask 1.1: 梳理手机界面如何打开 `wechat_main_panel`
  - [x] SubTask 1.2: 梳理聊天列表、联系人列表、聊天会话、朋友圈面板当前的复用关系
  - [x] SubTask 1.3: 确认哪些旧节点名和路径会因三列式重构发生变化

- [x] Task 2: 重构微聊主界面为居中三列式布局
  - [x] SubTask 2.1: 将微聊主界面改为屏幕中央独立窗口
  - [x] SubTask 2.2: 实现左侧纵向图标导航、中间列表区、右侧内容区
  - [x] SubTask 2.3: 实现聊天模式默认激活与空状态展示

- [x] Task 3: 重构聊天与联系人双模式联动
  - [x] SubTask 3.1: 聊天模式下接入聊天列表到右侧会话区的联动
  - [x] SubTask 3.2: 联系人模式下接入联系人列表到右侧详情区的联动
  - [x] SubTask 3.3: 实现联系人详情中的“发消息”跳转聊天流程

- [x] Task 4: 新增独立语音/视频通话窗口
  - [x] SubTask 4.1: 设计并接入可拖动的语音通话面板
  - [x] SubTask 4.2: 设计并接入可拖动的视频通话面板
  - [x] SubTask 4.3: 限制通话窗口拖动范围，保证不会超出屏幕

- [x] Task 5: 调整朋友圈入口为独立弹出逻辑
  - [x] SubTask 5.1: 将左侧朋友圈入口改为打开独立朋友圈面板
  - [x] SubTask 5.2: 确认不会错误复用右侧内容区

- [x] Task 6: 回归验证微聊主流程
  - [x] SubTask 6.1: 验证微聊从手机入口打开后为居中三列式窗口
  - [x] SubTask 6.2: 验证聊天、联系人、朋友圈三种入口切换正常
  - [x] SubTask 6.3: 验证联系人详情跳转聊天、语音聊天、视频聊天流程正常
  - [x] SubTask 6.4: 验证通话窗口拖动边界与空状态展示正常

# Task Dependencies
- [Task 2] depends on [Task 1]
- [Task 3] depends on [Task 2]
- [Task 4] depends on [Task 2]
- [Task 5] depends on [Task 2]
- [Task 6] depends on [Task 3], [Task 4], [Task 5]
