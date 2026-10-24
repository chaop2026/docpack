import asyncio
from playwright.async_api import async_playwright
from PIL import Image, ImageDraw
INK,CREAM="#1A1613","#F6F4EE"
FONT="font-family:'Noto Sans CJK JP',sans-serif;"
LOGO=f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
<rect width="400" height="400" fill="{INK}"/>
<path d="M296 104 H154 a36 36 0 0 0 0 72 H246 a50 50 0 0 1 0 100 H214" fill="none" stroke="{CREAM}" stroke-width="58" stroke-linecap="round"/>
<rect x="104" y="247" width="80" height="58" rx="29" fill="{CREAM}"/>
</svg>"""
HEAD=f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1500 500">
<rect width="1500" height="500" fill="{INK}"/>
<text x="110" y="215" font-size="76" font-weight="900" fill="{CREAM}" style="{FONT}">提出先のルールどおりに、</text>
<text x="110" y="315" font-size="76" font-weight="900" fill="{CREAM}" style="{FONT}">自動で正しく</text>
<rect x="556" y="252" width="300" height="80" rx="12" fill="{CREAM}"/>
<text x="110" y="400" font-size="34" fill="{CREAM}" opacity="0.7" style="{FONT}">ファイルはブラウザの外に出ません。 slimfile.net/safe/jp/</text>
</svg>"""
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(); pg=await b.new_page()
        for name,svg,w,h in [("logo_B2",LOGO,400,400),("header_B2",HEAD,1500,500)]:
            await pg.set_viewport_size({"width":w,"height":h})
            await pg.set_content(f"<body style='margin:0'>{svg.replace('viewBox',f'width=\"{w}\" height=\"{h}\" viewBox')}</body>")
            await pg.wait_for_timeout(200); await pg.screenshot(path=f"{name}.png")
            open(f"{name}.svg","w").write(svg)
        await b.close()
asyncio.run(main())
# preview: circle at 400 and 48
im=Image.open("logo_B2.png").convert("RGBA")
sheet=Image.new("RGB",(640,480),"white")
for size,x in [(400,20),(96,460),(48,580)]:
    s=im.resize((size,size),Image.LANCZOS); m=Image.new("L",(size,size),0); ImageDraw.Draw(m).ellipse((0,0,size-1,size-1),fill=255)
    sheet.paste(s,(x,40),m)
sheet.save("preview_B2.png")
