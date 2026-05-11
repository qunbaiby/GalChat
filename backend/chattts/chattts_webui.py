import os
os.environ["GRADIO_SERVER_PORT"] = "8082"
os.environ["GRADIO_SERVER_NAME"] = "0.0.0.0"
os.environ["NO_PROXY"] = "localhost,127.0.0.1,0.0.0.0"

import ChatTTS
import torch
import numpy as np
import gradio as gr
import os

print("正在初始化 ChatTTS...")
chat = ChatTTS.Chat()
chat.load(compile=False) # 如果显存/内存不足，可以加上 source='local' 等参数

def synthesize(text, voice_seed, speed):
    if not text:
        return None
        
    print(f"合成文本: {text} | 音色种子: {voice_seed}")
    
    # 设定种子以获取特定的音色
    torch.manual_seed(int(voice_seed))
    rand_spk = chat.sample_random_speaker()
    
    params_infer_code = ChatTTS.Chat.InferCodeParams(
        spk_emb = rand_spk,
    )
    
    wavs = chat.infer([text], params_infer_code=params_infer_code)
    
    # ChatTTS 返回的通常是 24000 采样率的数据
    audio_data = wavs[0]
    
    # 确保音频数据是一维的，适合 Gradio 播放
    if isinstance(audio_data, torch.Tensor):
        audio_data = audio_data.cpu().numpy()
    
    if len(audio_data.shape) > 1:
        audio_data = audio_data.squeeze()
        
    # 直接将 numpy 数组返回给 Gradio，无需保存文件
    return (24000, audio_data)

# 构建 Gradio 界面
with gr.Blocks(title="ChatTTS 音色测试台") as demo:
    gr.Markdown("# 🎧 ChatTTS 本地音色测试台")
    gr.Markdown("在这里可以调整随机种子 (Voice Seed) 来测试不同的音色，挑选满意的数字后填入 Godot 游戏的设置中。")
    
    with gr.Row():
        with gr.Column():
            text_input = gr.Textbox(label="测试文本", lines=3, value="你好呀！我是测试语音，很高兴认识你哦～")
            seed_input = gr.Number(label="音色种子 (Voice Seed)", value=2222, precision=0)
            speed_input = gr.Slider(label="语速", minimum=0.5, maximum=2.0, value=1.0, step=0.1)
            submit_btn = gr.Button("生成语音", variant="primary")
            
        with gr.Column():
            audio_output = gr.Audio(label="合成结果", type="numpy", format="wav")
            
    submit_btn.click(
        fn=synthesize,
        inputs=[text_input, seed_input, speed_input],
        outputs=[audio_output]
    )

if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=8082, inbrowser=False)