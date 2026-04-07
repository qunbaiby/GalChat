import sys
try:
    import PyPDF2
    reader = PyPDF2.PdfReader('e:\\GalChat_APP\\AI养成陪伴游戏「人格系统完整策划案」.pdf')
    text = '\n'.join(page.extract_text() for page in reader.pages)
    with open('e:\\GalChat_APP\\assets\\data\\temp_pdf_text.md', 'w', encoding='utf-8') as f:
        f.write(text)
    print("Success")
except Exception as e:
    print(f"Error: {e}")
