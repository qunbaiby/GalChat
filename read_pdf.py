import PyPDF2
with open("e:/GalChat_APP/Godot 4 C# （Windows 专属）外部应用窗口识别 完整落地方案.pdf", "rb") as f:
    reader = PyPDF2.PdfReader(f)
    text = ""
    for p in reader.pages:
        text += p.extract_text() + "\n"
with open("e:/GalChat_APP/out.txt", "w", encoding="utf-8") as out:
    out.write(text)