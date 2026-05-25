# Build Godot Editor MCP Spec

## Why
在纯文本的 AI 交互中，AI 难以直接理解 Godot 编辑器特有的场景树（Scene Tree）、`.tscn` 文件结构和节点路径（NodePath）。为了减少“节点找不到”或“信号未连接”等运行报错，需要开发一个专门的 Godot Editor MCP，允许 AI 能够直接读取当前 Godot 编辑器状态、场景树，甚至验证节点属性。

## What Changes
- 创建一个 Godot 编辑器插件（Godot Editor Plugin），在编辑器运行时启动一个本地 HTTP 服务器，暴露获取场景树、节点信息的接口。
- 创建一个基于 Node.js/TypeScript 的 MCP Server（Model Context Protocol），封装对 Godot 插件的 HTTP 请求，并向 AI 提供标准化的交互工具。

## Impact
- Affected specs: 提升 AI 对项目 UI 和场景结构的理解与代码生成准确率。
- Affected code:
  - 新增 Godot 插件 `addons/godot_mcp/`
  - 新增 Node.js MCP Server 项目 `mcp_servers/godot_editor/`

## ADDED Requirements
### Requirement: Godot Editor Plugin
- 插件激活时启动本地 HTTP Server（如监听端口 8081）。
- 提供获取当前编辑场景树结构（Node 层级）的接口。
- 提供获取指定节点属性的接口。

### Requirement: MCP Server
- 实现 MCP 协议，暴露供 AI 调用的 tools。
- 提供 `godot_get_scene_tree` 工具，返回当前编辑的场景树。
- 提供 `godot_get_node_info` 工具，返回指定 NodePath 的详细信息。
