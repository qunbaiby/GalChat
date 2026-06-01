# Godot Editor MCP

本目录包含一套本地 Godot 编辑器 MCP。

## 结构

- `index.ts`
  - Node 侧 MCP Server
  - 负责暴露 MCP 工具
  - 负责项目启动、HTTP 请求封装、状态检查
- `../../addons/godot_mcp`
  - Godot 编辑器插件
  - 负责把编辑器内的信息通过本地 HTTP 暴露出来

## 当前工具

- `godot_editor_status`
- `godot_project_open`
- `godot_project_run`
- `godot_get_scene_tree`
- `godot_get_current_scene`
- `godot_get_selected_node`
- `godot_find_node`
- `godot_get_node_info`
- `godot_open_scene`
- `godot_set_node_property`
- `godot_save_scene`
- `godot_save_all_scenes`
- `godot_get_editor_logs`

其中：

- `godot_editor_status`
  - 检查插件在线状态、当前项目、当前场景与选中节点数量
- `godot_project_open`
  - 从 MCP 侧启动 Godot 编辑器并打开项目
- `godot_project_run`
  - 通过已连接的编辑器运行主场景、当前场景或自定义场景
- `godot_open_scene`
  - 在编辑器中打开指定场景
- `godot_set_node_property`
  - 修改当前编辑场景中指定节点的属性
- `godot_save_scene`
  - 保存当前场景，或另存为到指定路径
- `godot_save_all_scenes`
  - 保存编辑器中所有已打开场景
- `godot_get_editor_logs`
  - 读取当前项目最近的 `user://logs/godot.log`

## 环境变量

- `GODOT_MCP_BASE_URL`
  - 默认 `http://127.0.0.1:8081`
- `GODOT_PROJECT_PATH`
  - 默认 `e:\GalChat\GalChat`
- `GODOT_EXECUTABLE`
  - Godot 可执行文件路径，供 `godot_project_open` 默认使用
- `GODOT_EDITOR_LOG_PATH`
  - 可选，显式指定日志文件路径，供 `godot_get_editor_logs` 优先使用

## 开发

```bash
npm install
npm run build
npm run start
```

## 调试

```bash
npm run inspector
```

## 使用前提

1. 在 Godot 编辑器中启用 `addons/godot_mcp` 插件。
2. 打开目标项目。
3. 如果需要通过 MCP 启动 Godot，先配置 `GODOT_EXECUTABLE` 或在工具调用时传入 `executable_path`。
