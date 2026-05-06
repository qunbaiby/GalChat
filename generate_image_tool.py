import os
import json
import time
import urllib.request
import urllib.error

# ================= 配置区 =================
# 你的 API KEY
API_KEY = "sk-2IzODQY0nFcQeGhE02375aB9A4204c3eBe12132f57EfD8Ce"

# 接口地址（如果你使用的是国内的中转代理接口，请将这里替换为代理 URL，例如 "https://api.chatanywhere.tech/v1/images/generations"）
API_URL = "https://api.openai.com/v1/images/generations"

# 使用的模型，支持 "dall-e-2" 或者 "dall-e-3"
MODEL = "dall-e-2" 

# 生成图片的尺寸: dall-e-2 支持 "256x256", "512x512", "1024x1024"
SIZE = "1024x1024"
# ==========================================

def generate_image(prompt, filename):
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {API_KEY}"
    }
    
    data = {
        "model": MODEL,
        "prompt": prompt,
        "n": 1,
        "size": SIZE
    }
    
    # 构建请求
    req = urllib.request.Request(API_URL, data=json.dumps(data).encode('utf-8'), headers=headers, method='POST')
    
    print(f"\n[*] 正在调用 API 生图...")
    print(f"[*] 模型: {MODEL} | 尺寸: {SIZE}")
    print(f"[*] 提示词: '{prompt}'")
    print(f"[*] 请耐心稍候...")
    
    try:
        # 发送请求，设置 60 秒超时
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode('utf-8'))
            image_url = result['data'][0]['url']
            print(f"[+] API 返回成功！正在下载图片...")
            
            # 下载图片到本地
            urllib.request.urlretrieve(image_url, filename)
            print(f"[+] 图片已成功保存到: {os.path.abspath(filename)}")
            
    except urllib.error.HTTPError as e:
        error_info = e.read().decode('utf-8')
        print(f"[-] API 请求失败: HTTP {e.code} {e.reason}")
        print(f"[-] 详细错误信息: {error_info}")
    except urllib.error.URLError as e:
        print(f"[-] 网络连接失败，请检查网络或代理设置: {e.reason}")
    except Exception as e:
        print(f"[-] 发生未知错误: {e}")

if __name__ == "__main__":
    print("========================================")
    print("          简易 OpenAI 生图工具          ")
    print("========================================")
    while True:
        prompt = input("\n请输入你要生成的图片提示词 (输入 q 退出): ").strip()
        if prompt.lower() == 'q':
            print("已退出工具。")
            break
        if not prompt:
            continue
            
        # 以当前时间戳命名文件，防止覆盖
        output_file = f"output_image_{int(time.time())}.png"
        generate_image(prompt, output_file)
