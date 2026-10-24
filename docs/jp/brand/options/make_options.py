import asyncio, os
from playwright.async_api import async_playwright

OUT = os.path.dirname(os.path.abspath(__file__))
FONT = "font-family:'Noto Sans CJK JP','Noto Sans JP',sans-serif;"
CREAM, INK, SAND, YEL = "#F6F4EE", "#1A1613", "#E8E3D8", "#FFD84D"

# ---- Option A: 기존 아이콘 계승 (문서 + 검은 띠, 크림 배경)
A = f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
<rect width="400" height="400" fill="{CREAM}"/>
<rect x="110" y="70" width="180" height="260" rx="14" fill="#fff" stroke="{SAND}" stroke-width="4"/>
<rect x="135" y="110" width="130" height="26" rx="7" fill="{INK}"/>
<rect x="135" y="152" width="110" height="12" rx="6" fill="{SAND}"/>
<rect x="135" y="176" width="90" height="12" rx="6" fill="{SAND}"/>
<rect x="135" y="214" width="92" height="26" rx="7" fill="{INK}"/>
<rect x="135" y="256" width="110" height="12" rx="6" fill="{SAND}"/>
<rect x="135" y="280" width="70" height="12" rx="6" fill="{SAND}"/>
</svg>"""

# ---- Option B: 「S」 모노그램 — 검은 띠가 S자를 이룸 (검은 배경, 강한 식별성)
B = f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
<rect width="400" height="400" fill="{INK}"/>
<path d="M290 120 H150 a30 30 0 0 0 0 60 H250 a44 44 0 0 1 0 88 H110" fill="none" stroke="{CREAM}" stroke-width="44" stroke-linecap="round"/>
<rect x="196" y="246" width="94" height="44" rx="10" fill="{YEL}"/>
</svg>"""

# ---- Option C: 「黒塗り」 — 일본어 문자 일부를 검은 띠로 가린 형태 (크림 배경, 日本向け 메시지)
C = f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
<rect width="400" height="400" fill="{CREAM}"/>
<text x="200" y="196" text-anchor="middle" font-size="124" font-weight="900" fill="{INK}" style="{FONT}">黒塗</text>
<rect x="74" y="232" width="252" height="52" rx="10" fill="{INK}"/>
<text x="200" y="344" text-anchor="middle" font-size="40" font-weight="700" fill="{INK}" letter-spacing="2" style="{FONT}">SafeFile</text>
</svg>"""

# ---- Option D: 방패 + 띠 (보안 코드, 노란 포인트)
D = f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
<rect width="400" height="400" fill="{YEL}"/>
<path d="M200 56 L312 96 V200 C312 268 262 318 200 344 C138 318 88 268 88 200 V96 Z" fill="{INK}"/>
<rect x="132" y="150" width="136" height="26" rx="7" fill="{CREAM}"/>
<rect x="132" y="192" width="100" height="14" rx="7" fill="#8E867A"/>
<rect x="132" y="220" width="116" height="26" rx="7" fill="{CREAM}"/>
</svg>"""

OPTS = {"A": A, "B": B, "C": C, "D": D}

# 헤더(1500x500) 미리보기 — 각 옵션 톤에 맞춰 1개씩
def header(opt):
    bg, fg = (INK, CREAM) if opt in "B" else (CREAM, INK)
    return f"""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1500 500">
<rect width="1500" height="500" fill="{bg}"/>
<text x="110" y="215" font-size="76" font-weight="900" fill="{fg}" style="{FONT}">提出先のルールどおりに、</text>
<text x="110" y="315" font-size="76" font-weight="900" fill="{fg}" style="{FONT}">自動で正しく</text>
<rect x="556" y="252" width="300" height="80" rx="12" fill="{fg}"/>
<text x="110" y="400" font-size="34" fill="{fg}" opacity="0.75" style="{FONT}">ファイルはブラウザの外に出ません。 slimfile.net/safe/jp/</text>
</svg>"""

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page(device_scale_factor=1)
        for k, svg in OPTS.items():
            await pg.set_viewport_size({"width": 400, "height": 400})
            await pg.set_content(f"<html><body style='margin:0'>{svg.replace('viewBox', 'width=\"400\" height=\"400\" viewBox')}</body></html>")
            await pg.wait_for_timeout(200)
            await pg.screenshot(path=f"{OUT}/logo_{k}.png", clip={"x":0,"y":0,"width":400,"height":400})
            open(f"{OUT}/logo_{k}.svg","w").write(svg)
        for k in "AB":
            await pg.set_viewport_size({"width": 1500, "height": 500})
            await pg.set_content(f"<html><body style='margin:0'>{header(k).replace('viewBox', 'width=\"1500\" height=\"500\" viewBox')}</body></html>")
            await pg.wait_for_timeout(200)
            await pg.screenshot(path=f"{OUT}/header_{k}.png", clip={"x":0,"y":0,"width":1500,"height":500})
        # 4안 비교 시트
        await pg.set_viewport_size({"width": 1760, "height": 520})
        imgs = "".join(f"<div style='text-align:center;{FONT}font-size:22px;color:#1A1613'><img src='file://{OUT}/logo_{k}.png' width='400' style='border-radius:50%;display:block;margin-bottom:12px'/>{k}</div>" for k in OPTS)
        await pg.set_content(f"<html><body style='margin:0;background:#fff;display:flex;gap:40px;padding:40px'>{imgs}</body></html>")
        await pg.wait_for_timeout(300)
        await pg.screenshot(path=f"{OUT}/contact_sheet.png", full_page=True)
        await b.close()

asyncio.run(main())
