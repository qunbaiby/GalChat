import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import os from "node:os";
import pathModule from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
const GODOT_HTTP_BASE = process.env.GODOT_MCP_BASE_URL ?? "http://127.0.0.1:8081";
const DEFAULT_PROJECT_PATH = process.env.GODOT_PROJECT_PATH ?? "e:\\GalChat\\GalChat";
const DEFAULT_GODOT_EXECUTABLE = process.env.GODOT_EXECUTABLE ?? "";
const DEFAULT_EDITOR_LOG_PATH = process.env.GODOT_EDITOR_LOG_PATH ?? "";
const HTTP_TIMEOUT_MS = 2500;
let managedGodotProcess = null;
const server = new McpServer({
    name: "godot_editor",
    version: "1.2.0"
});
function buildUrl(pathname, params) {
    const url = new URL(pathname, GODOT_HTTP_BASE);
    if (params) {
        for (const [key, value] of Object.entries(params)) {
            if (value !== undefined && value !== "") {
                url.searchParams.set(key, String(value));
            }
        }
    }
    return url.toString();
}
async function requestJson(pathname, options) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), HTTP_TIMEOUT_MS);
    try {
        const method = options?.method ?? "GET";
        const response = await fetch(buildUrl(pathname, options?.params), {
            method,
            signal: controller.signal,
            headers: options?.body ? { "Content-Type": "application/json" } : undefined,
            body: options?.body ? JSON.stringify(options.body) : undefined
        });
        const text = await response.text();
        let parsed = {};
        if (text.trim() !== "") {
            parsed = JSON.parse(text);
        }
        if (!response.ok) {
            const errorMessage = typeof parsed.error === "string"
                ? parsed.error
                : `HTTP error ${response.status}`;
            throw new Error(errorMessage);
        }
        return parsed;
    }
    catch (error) {
        if (error instanceof Error && error.name === "AbortError") {
            throw new Error("连接 Godot 插件超时，请确认 Godot 编辑器已启动且插件已启用");
        }
        throw error;
    }
    finally {
        clearTimeout(timeout);
    }
}
function toolSuccess(data) {
    return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
        structuredContent: data
    };
}
function toolError(message) {
    return {
        content: [{ type: "text", text: message }],
        isError: true
    };
}
async function fileExists(filePath) {
    try {
        await fs.access(filePath);
        return true;
    }
    catch {
        return false;
    }
}
function getGodotDataRoot() {
    if (process.platform === "win32") {
        const appData = process.env.APPDATA ?? pathModule.join(os.homedir(), "AppData", "Roaming");
        return pathModule.join(appData, "Godot");
    }
    if (process.platform === "darwin") {
        return pathModule.join(os.homedir(), "Library", "Application Support", "Godot");
    }
    const xdgDataHome = process.env.XDG_DATA_HOME ?? pathModule.join(os.homedir(), ".local", "share");
    return pathModule.join(xdgDataHome, "godot");
}
async function getProjectName(projectPath) {
    const projectFilePath = pathModule.join(projectPath, "project.godot");
    try {
        const projectText = await fs.readFile(projectFilePath, "utf8");
        const match = projectText.match(/^\s*config\/name="((?:[^"\\]|\\.)*)"/m);
        if (match) {
            return match[1].replace(/\\"/g, "\"");
        }
    }
    catch {
        // 回退到目录名，避免日志工具完全不可用。
    }
    return pathModule.basename(projectPath);
}
async function resolveEditorLogPath(projectPath, explicitLogPath) {
    const directCandidates = [explicitLogPath, DEFAULT_EDITOR_LOG_PATH].filter((candidate) => typeof candidate === "string" && candidate.trim() !== "");
    for (const candidate of directCandidates) {
        if (await fileExists(candidate)) {
            return candidate;
        }
    }
    const projectName = await getProjectName(projectPath);
    const logDirectory = pathModule.join(getGodotDataRoot(), "app_userdata", projectName, "logs");
    const currentLogPath = pathModule.join(logDirectory, "godot.log");
    if (await fileExists(currentLogPath)) {
        return currentLogPath;
    }
    try {
        const entries = await fs.readdir(logDirectory, { withFileTypes: true });
        const logFiles = await Promise.all(entries
            .filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".log"))
            .map(async (entry) => {
            const fullPath = pathModule.join(logDirectory, entry.name);
            const stats = await fs.stat(fullPath);
            return {
                fullPath,
                modifiedAt: stats.mtimeMs
            };
        }));
        logFiles.sort((left, right) => right.modifiedAt - left.modifiedAt);
        if (logFiles.length > 0) {
            return logFiles[0].fullPath;
        }
    }
    catch {
        // 目录不存在或无法读取时，返回默认推断路径供报错信息使用。
    }
    return directCandidates[0] ?? currentLogPath;
}
function tailTextLines(text, maxLines) {
    const normalizedText = text.replace(/\r\n/g, "\n");
    const lines = normalizedText.split("\n");
    const effectiveLines = lines.length > 0 && lines[lines.length - 1] === ""
        ? lines.slice(0, -1)
        : lines;
    const safeMaxLines = Math.max(maxLines, 1);
    const startIndex = Math.max(effectiveLines.length - safeMaxLines, 0);
    return {
        total_lines: effectiveLines.length,
        returned_lines: effectiveLines.length - startIndex,
        truncated: startIndex > 0,
        log_text: effectiveLines.slice(startIndex).join("\n")
    };
}
async function fetchEditorStatus() {
    try {
        const health = await requestJson("/health");
        let status = {};
        try {
            status = await requestJson("/editor_status");
        }
        catch {
            status = {};
        }
        return {
            online: true,
            base_url: GODOT_HTTP_BASE,
            health,
            status,
            managed_process_pid: managedGodotProcess?.pid ?? null
        };
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
            online: false,
            base_url: GODOT_HTTP_BASE,
            managed_process_pid: managedGodotProcess?.pid ?? null,
            error: `Godot 插件不可用：${message}`
        };
    }
}
server.tool("godot_editor_status", "检查 Godot 编辑器插件是否在线，并返回当前项目、场景和选择状态。", {}, async () => {
    const result = await fetchEditorStatus();
    return toolSuccess(result);
});
server.tool("godot_project_open", "启动 Godot 编辑器并打开指定项目。优先使用传入的 executable_path，其次使用 GODOT_EXECUTABLE 环境变量。", {
    project_path: z.string().optional().describe("Godot 项目路径，默认使用当前项目路径"),
    executable_path: z.string().optional().describe("Godot 可执行文件路径，例如 Godot_v4.5.1-stable_mono_win64.exe"),
    headless: z.boolean().optional().describe("是否以 headless 模式启动，默认 false")
}, async ({ project_path, executable_path, headless }) => {
    const resolvedProjectPath = project_path || DEFAULT_PROJECT_PATH;
    const resolvedExecutablePath = executable_path || DEFAULT_GODOT_EXECUTABLE;
    if (!resolvedExecutablePath) {
        return toolError("缺少 Godot 可执行文件路径。请传入 executable_path，或设置 GODOT_EXECUTABLE 环境变量。");
    }
    if (managedGodotProcess && managedGodotProcess.exitCode === null && !managedGodotProcess.killed) {
        return toolSuccess({
            opened: false,
            message: "已有由 MCP 启动的 Godot 进程在运行。",
            pid: managedGodotProcess.pid ?? null
        });
    }
    const args = ["--path", resolvedProjectPath, "--editor"];
    if (headless) {
        args.push("--headless");
    }
    managedGodotProcess = spawn(resolvedExecutablePath, args, {
        detached: true,
        stdio: "ignore"
    });
    managedGodotProcess.unref();
    return toolSuccess({
        opened: true,
        executable_path: resolvedExecutablePath,
        project_path: resolvedProjectPath,
        pid: managedGodotProcess.pid ?? null,
        message: "已请求启动 Godot 编辑器。稍候可调用 godot_editor_status 检查插件是否在线。"
    });
});
server.tool("godot_project_run", "通过当前已连接的 Godot 编辑器运行主场景、当前场景或自定义场景。", {
    mode: z.enum(["main", "current", "custom"]).optional().describe("运行模式：main、current、custom，默认 main"),
    scene_path: z.string().optional().describe("自定义运行场景路径，仅 mode=custom 时需要")
}, async ({ mode, scene_path }) => {
    try {
        const data = await requestJson("/play_scene", {
            method: "POST",
            body: {
                mode: mode ?? "main",
                scene_path: scene_path ?? ""
            }
        });
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`运行项目失败：${message}`);
    }
});
server.tool("godot_get_scene_tree", "获取 Godot 当前编辑场景的完整场景树。", {}, async () => {
    try {
        const data = await requestJson("/scene_tree");
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`获取场景树失败：${message}`);
    }
});
server.tool("godot_get_current_scene", "获取 Godot 当前正在编辑的场景信息，包括场景路径、根节点和子节点数量。", {}, async () => {
    try {
        const data = await requestJson("/current_scene");
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`获取当前场景失败：${message}`);
    }
});
server.tool("godot_get_selected_node", "获取 Godot 编辑器当前选中的节点信息，支持多选。", {}, async () => {
    try {
        const data = await requestJson("/selected_node");
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`获取当前选中节点失败：${message}`);
    }
});
server.tool("godot_find_node", "按名称、类型或路径片段在当前编辑场景中搜索节点。", {
    name: z.string().optional().describe("节点名称包含的关键字"),
    class_name: z.string().optional().describe("节点类型包含的关键字，例如 Button、TextureRect"),
    path_contains: z.string().optional().describe("节点路径包含的关键字"),
    limit: z.number().int().min(1).max(100).optional().describe("最多返回的节点数量，默认 20")
}, async ({ name, class_name, path_contains, limit }) => {
    try {
        const data = await requestJson("/find_node", {
            params: {
                name,
                class_name,
                path_contains,
                limit
            }
        });
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`搜索节点失败：${message}`);
    }
});
server.tool("godot_get_node_info", "获取 Godot 场景树中指定节点的详细信息和属性列表。", {
    path: z.string().describe("节点在场景树中的路径，例如 /root/Main/Player")
}, async ({ path }) => {
    try {
        const data = await requestJson("/node", { params: { path } });
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`获取节点信息失败：${message}`);
    }
});
server.tool("godot_open_scene", "在 Godot 编辑器中打开指定场景文件。", {
    scene_path: z.string().describe("要打开的场景路径，例如 res://scenes/ui/main/main_scene.tscn"),
    set_inherited: z.boolean().optional().describe("是否以继承场景方式打开，默认 false")
}, async ({ scene_path, set_inherited }) => {
    try {
        const data = await requestJson("/open_scene", {
            method: "POST",
            body: {
                scene_path,
                set_inherited: set_inherited ?? false
            }
        });
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`打开场景失败：${message}`);
    }
});
server.tool("godot_set_node_property", "设置当前编辑场景中指定节点的属性值。支持 string、int、float、bool、json、vector2、vector2i、vector3、vector3i、color、node_path。", {
    path: z.string().describe("节点路径，例如 /root/MainScene/UIPanel/MapButton"),
    property: z.string().describe("属性名，例如 text、visible、position、modulate"),
    value: z.any().describe("属性值"),
    value_type: z.string().optional().describe("值类型，默认 auto")
}, async ({ path, property, value, value_type }) => {
    try {
        const data = await requestJson("/set_node_property", {
            method: "POST",
            body: {
                path,
                property,
                value,
                value_type: value_type ?? "auto"
            }
        });
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`设置节点属性失败：${message}`);
    }
});
server.tool("godot_save_scene", "保存当前编辑场景。若传入 scene_path，则另存为该路径。", {
    scene_path: z.string().optional().describe("保存路径，默认保存到当前场景原路径"),
    with_preview: z.boolean().optional().describe("是否生成预览图，默认 false")
}, async ({ scene_path, with_preview }) => {
    try {
        const body = {
            with_preview: with_preview ?? false
        };
        if (scene_path) {
            body.scene_path = scene_path;
        }
        const data = await requestJson("/save_scene", {
            method: "POST",
            body
        });
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`保存场景失败：${message}`);
    }
});
server.tool("godot_save_all_scenes", "保存 Godot 编辑器中当前已打开的全部场景。", {}, async () => {
    try {
        const data = await requestJson("/save_all_scenes", {
            method: "POST",
            body: {}
        });
        return toolSuccess(data);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`保存全部场景失败：${message}`);
    }
});
server.tool("godot_get_editor_logs", "读取最近的 Godot 运行日志，默认定位到当前项目的 user://logs/godot.log。", {
    project_path: z.string().optional().describe("Godot 项目路径，默认使用当前项目路径"),
    log_path: z.string().optional().describe("显式指定日志文件路径，优先级最高"),
    line_count: z.number().int().min(1).max(2000).optional().describe("返回最后多少行日志，默认 200")
}, async ({ project_path, log_path, line_count }) => {
    const resolvedProjectPath = project_path || DEFAULT_PROJECT_PATH;
    const resolvedLineCount = line_count ?? 200;
    try {
        const resolvedLogPath = await resolveEditorLogPath(resolvedProjectPath, log_path);
        if (!(await fileExists(resolvedLogPath))) {
            return toolError(`未找到 Godot 日志文件：${resolvedLogPath}`);
        }
        const logContent = await fs.readFile(resolvedLogPath, "utf8");
        return toolSuccess({
            project_path: resolvedProjectPath,
            log_path: resolvedLogPath,
            ...tailTextLines(logContent, resolvedLineCount)
        });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return toolError(`读取编辑器日志失败：${message}`);
    }
});
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error(`Godot Editor MCP Server running on stdio (${GODOT_HTTP_BASE})`);
}
main().catch((error) => {
    console.error("Server error:", error);
    process.exit(1);
});
