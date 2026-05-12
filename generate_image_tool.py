import os
import json
import time
import urllib.request
import urllib.error
import gradio as gr

# ================= 预设服务商配置 =================
PRESETS = {
    "OpenAI 官方 (ChatGPT)": {
        "url": "https://api.openai.com/v1/images/generations",
        "models": ["dall-e-3", "dall-e-2"],
        "default_model": "dall-e-3"
    },
    "Nano Banana (或其他中转代理)": {
        "url": "https://api.nanobanana.com/v1/images/generations", # 请替换为实际的 Nano Banana 接口地址
        "models": ["dall-e-3", "dall-e-2", "midjourney"],
        "default_model": "dall-e-3"
    },
    "豆包 (Doubao - 火山引擎官方)": {
        # 注意：火山引擎的图片生成接口路径与标准 OpenAI 不同
        "url": "https://ark.cn-beijing.volces.com/api/v3/bots", 
        "models": ["ep-xxxxxxxx-xxx", "请手动将模型名称替换为您的火山引擎接入点ID(ep-开头)"], 
        "default_model": "ep-xxxxxxxx-xxx"
    },
    "自定义接口 (Custom)": {
        "url": "https://api.chatanywhere.tech/v1/images/generations",
        "models": ["dall-e-3", "dall-e-2", "mj-chat"],
        "default_model": "dall-e-3"
    }
}

def update_presets(provider):
    preset = PRESETS.get(provider, PRESETS["自定义接口 (Custom)"])
    return preset["url"], gr.update(choices=preset["models"], value=preset["default_model"])

def generate_image(api_key, api_url, model, prompt, size):
    if not api_key or not api_url or not prompt:
        return None, "错误：API Key、接口地址和提示词不能为空！"
        
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    }
    
    data = {
        "model": model,
        "prompt": prompt,
        "n": 1,
        "size": size
    }
    
    # 针对火山引擎豆包的特殊数据格式适配
    if "volces.com" in api_url:
        data = {
            "model": model,
            "messages": [
                {"role": "user", "content": prompt}
            ]
        }
    
    try:
        req = urllib.request.Request(api_url, data=json.dumps(data).encode('utf-8'), headers=headers, method='POST')
        
        # 为了解决 WinError 10060 (连接超时/无响应) 问题，如果是国内直连地址，取消代理限制
        if "volces.com" in api_url or "nanobanana" in api_url:
            proxy_handler = urllib.request.ProxyHandler({}) # 使用空代理（直连）
            opener = urllib.request.build_opener(proxy_handler)
            urllib.request.install_opener(opener)
            
        with urllib.request.urlopen(req, timeout=120) as response:
            result = json.loads(response.read().decode('utf-8'))
            
            # 解析不同平台的返回结构
            image_url = None
            if "volces.com" in api_url:
                # 豆包 Bots API 的返回结构通常在 choices[0].message.content 中，可能需要提取 markdown 图片链接
                if 'choices' in result and len(result['choices']) > 0:
                    content = result['choices'][0]['message'].get('content', '')
                    import re
                    # 尝试从 markdown ![alt](url) 中提取 URL
                    match = re.search(r'!\[.*?\]\((.*?)\)', content)
                    if match:
                        image_url = match.group(1)
            else:
                # 标准 OpenAI 结构
                if 'data' in result and len(result['data']) > 0:
                    image_url = result['data'][0].get('url')
                    
            if not image_url:
                return None, f"API 响应中未找到图片 URL: {result}"
                
            # 下载图片到本地
            output_dir = "outputs"
            if not os.path.exists(output_dir):
                os.makedirs(output_dir)
                
            filename = os.path.join(output_dir, f"img_{int(time.time())}.png")
            urllib.request.urlretrieve(image_url, filename)
            
            return filename, f"✅ 生成成功！图片已保存至项目根目录的 outputs 文件夹下。\n本地路径: {os.path.abspath(filename)}"
                
    except urllib.error.HTTPError as e:
        error_info = e.read().decode('utf-8')
        return None, f"❌ API 请求失败: HTTP {e.code} {e.reason}\n详细信息: {error_info}"
    except Exception as e:
        return None, f"❌ 发生未知错误: {str(e)}"

# ================= 构建 WebUI =================
with gr.Blocks(title="AI 绘图 WebUI", theme=gr.themes.Soft()) as demo:
    gr.Markdown("## 🎨 多模型 AI 生图 WebUI 工具\n支持 OpenAI、Nano Banana、豆包 等标准的 OpenAI 格式兼容接口。")
    
    with gr.Row():
        with gr.Column(scale=1):
            provider_dd = gr.Dropdown(list(PRESETS.keys()), label="快捷服务商预设", value="OpenAI 官方 (ChatGPT)")
            api_key_input = gr.Textbox(label="API Key", type="password", placeholder="输入你的 sk-...", value="sk-2IzODQY0nFcQeGhE02375aB9A4204c3eBe12132f57EfD8Ce")
            api_url_input = gr.Textbox(label="接口地址 (API URL)", value=PRESETS["OpenAI 官方 (ChatGPT)"]["url"])
            model_dd = gr.Dropdown(choices=PRESETS["OpenAI 官方 (ChatGPT)"]["models"], label="模型名称 (Model)", value=PRESETS["OpenAI 官方 (ChatGPT)"]["default_model"], allow_custom_value=True)
            size_dd = gr.Dropdown(choices=["1024x1024", "512x512", "256x256", "1024x1792", "1792x1024"], label="图片尺寸", value="1024x1024", allow_custom_value=True)
            
        with gr.Column(scale=2):
            prompt_input = gr.Textbox(label="提示词 (Prompt)", lines=5, placeholder="描述你想生成的图片内容（例如：一只在赛博朋克城市里喝咖啡的可爱猫咪，8k，超高画质）...")
            generate_btn = gr.Button("🚀 立即生成图片", variant="primary")
            
            with gr.Row():
                output_image = gr.Image(label="生成的图片预览", type="filepath")
            output_info = gr.Textbox(label="运行日志与结果", interactive=False)
            
    # 事件绑定
    provider_dd.change(
        fn=update_presets,
        inputs=[provider_dd],
        outputs=[api_url_input, model_dd]
    )
    
    generate_btn.click(
        fn=generate_image,
        inputs=[api_key_input, api_url_input, model_dd, prompt_input, size_dd],
        outputs=[output_image, output_info]
    )

if __name__ == "__main__":
    print("========================================")
    print("      正在启动 AI 绘图 WebUI...         ")
    print("========================================")
    
    # 修复开启 VPN/代理 导致的 Gradio 502 本地环回报错
    os.environ["NO_PROXY"] = "localhost,127.0.0.1,::1"
    
    # 启动 Gradio 服务，自动在浏览器中打开
    demo.launch(inbrowser=True, server_name="127.0.0.1", server_port=7860)
