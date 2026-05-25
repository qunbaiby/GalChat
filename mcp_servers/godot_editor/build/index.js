import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
const server = new McpServer({
    name: "godot_editor",
    version: "1.0.0"
});
// Tool 1: godot_get_scene_tree
server.tool("godot_get_scene_tree", "获取 Godot 当前运行的场景树", {}, async () => {
    try {
        const response = await fetch("http://127.0.0.1:8081/scene_tree");
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.text();
        return {
            content: [{ type: "text", text: data }]
        };
    }
    catch (error) {
        return {
            content: [{ type: "text", text: `Error fetching scene tree: ${error.message}` }],
            isError: true
        };
    }
});
// Tool 2: godot_get_node_info
server.tool("godot_get_node_info", "获取 Godot 场景树中指定节点的信息", {
    path: z.string().describe("节点在场景树中的路径 (例如 /root/Main/Player)")
}, async ({ path }) => {
    try {
        const url = new URL("http://127.0.0.1:8081/node");
        url.searchParams.append("path", path);
        const response = await fetch(url.toString());
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.text();
        return {
            content: [{ type: "text", text: data }]
        };
    }
    catch (error) {
        return {
            content: [{ type: "text", text: `Error fetching node info: ${error.message}` }],
            isError: true
        };
    }
});
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("Godot Editor MCP Server running on stdio");
}
main().catch((error) => {
    console.error("Server error:", error);
    process.exit(1);
});
