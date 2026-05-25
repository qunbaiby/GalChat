# Tasks
- [x] Task 1: 创建 Godot Editor Plugin
  - [x] SubTask 1.1: 在 `addons/godot_mcp` 下初始化插件配置文件 `plugin.cfg` 和核心入口脚本。
  - [x] SubTask 1.2: 实现一个基于 `TCPServer` 的简易 HTTP 服务器，监听指定端口（如 8081）。
  - [x] SubTask 1.3: 实现获取当前编辑器打开场景的根节点及遍历场景树逻辑，封装为 JSON 响应返回。
  - [x] SubTask 1.4: 实现获取指定 NodePath 节点属性（类名、脚本、属性列表）的逻辑。
- [x] Task 2: 创建 Node.js MCP Server
  - [x] SubTask 2.1: 在 `mcp_servers/godot_editor` 目录下初始化 Node.js/TypeScript 项目。
  - [x] SubTask 2.2: 安装 `@modelcontextprotocol/sdk` 依赖并搭建基础 MCP 框架。
  - [x] SubTask 2.3: 注册 `godot_get_scene_tree` 工具，向 Godot 插件发起请求并返回结果。
  - [x] SubTask 2.4: 注册 `godot_get_node_info` 工具，向 Godot 插件发起请求并返回节点详情。
- [x] Task 3: 联调与测试
  - [x] SubTask 3.1: 在 Godot 中激活插件，确保 HTTP 服务正常运行。
  - [x] SubTask 3.2: 运行 MCP Server，通过 inspector 或 AI 客户端验证工具调用。

# Task Dependencies
- Task 2 依赖于 Task 1 的接口定义。
- Task 3 依赖于 Task 1 和 Task 2 的完成。
