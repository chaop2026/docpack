#!/usr/bin/env python3
"""SafeFile JP alpha fixtures — 비실물 도식형 더미 4종 생성.
안전 조건: 실물 비율·색·서체·칸 배치 동시 재현 금지 / 대형 見本 표기 / 로고·관인·QR·IC 금지 /
체크디지트 불일치 번호 / 실존 불가 주소 / 架空 인명.
출력: out/<doc>/<variant>.{png,jpg,pdf} + specs.json (목적별 기대 마스킹 박스)
"""
import json, os, random, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4

random.seed(20261021)
OUT = os.path.join(os.path.dirname(__file__), "out")
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"
FONTB = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
if not os.path.exists(FONTB): FONTB = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"

def F(sz, bold=False): return ImageFont.truetype(FONTB if bold else FONT, sz, index=2)

# ---------- 架空 데이터 ----------
SURN = ["架空", "見本", "仮名", "試験", "例示", "模擬"]
GIVEN = ["太郎", "花子", "一郎", "美咲", "健太", "さくら"]
def name(): return random.choice(SURN) + " " + random.choice(GIVEN)
def kana(n): return {"架空":"カクウ","見本":"ミホン","仮名":"カメイ","試験":"シケン","例示":"レイジ","模擬":"モギ"}[n.split()[0]] + " " + {"太郎":"タロウ","花子":"ハナコ","一郎":"イチロウ","美咲":"ミサキ","健太":"ケンタ","さくら":"サクラ"}[n.split()[1]]
PREF = ["東京都", "大阪府", "神奈川県", "愛知県", "福岡県", "北海道"]
CITY = {"東京都":"架空区", "大阪府":"見本市", "神奈川県":"仮名市", "愛知県":"試験市", "福岡県":"例示市", "北海道":"模擬市"}
def addr():
    p = random.choice(PREF); return p + CITY[p] + f"架空町{random.randint(90,99)}丁目{random.randint(90,99)}番{random.randint(90,99)}号"
def postal(): return f"〒999-99{random.randint(10,99)}"
def wareki():
    era = random.choice([("昭和", 1926, 60), ("平成", 1989, 10)]); y = random.randint(40, 63) if era[0]=="昭和" else random.randint(1,10)
    return f"{era[0]}{y}年{random.randint(1,12)}月{random.randint(1,28)}日"
def mynumber_invalid():
    # 12자리, 마지막 자리 체크디지트를 일부러 불일치시킴 (mod11 계산 후 +1)
    d = [random.randint(0,9) for _ in range(11)]
    s = sum(d[i] * ((12 - (i+1)) % 6 + 1 if False else (6 - ((i+1) % 6) + 1) if False else 0) for i in range(11))  # placeholder
    # 실제 공식: Σ P_n*Q_n, Q_n = n+1 (n<=6) else n-5 ; check = 11 - (s mod 11) (if >=10 → 0)
    s = 0
    for n in range(1, 12):
        p = d[11 - n]; q = n + 1 if n <= 6 else n - 5; s += p * q
    chk = 11 - (s % 11); chk = 0 if chk >= 10 else chk
    bad = (chk + 1) % 10
    return "".join(map(str, d)) + str(bad)
def license_no(): return "9999" + "".join(str(random.randint(0,9)) for _ in range(7)) + "X"  # 규격 외 문자 포함
def hokensha(): return "99" + "".join(str(random.randint(0,9)) for _ in range(6))

# ---------- 공통 그리기 ----------
def mihon(d, W, H, text="見本・架空 / 本人確認に使用不可"):
    # 반투명 대각선 워터마크 레이어 — 글자 판독은 유지, 제거 불가
    layer = Image.new("RGBA", (W*2, H*2), (0,0,0,0)); ld = ImageDraw.Draw(layer)
    f = F(int(min(W,H)*0.07), True)
    tw = ld.textlength(text, font=f) + 80; step = int(min(W,H)*0.28)
    for yy in range(0, H*2, step):
        for xx in range(0, int(W*2), int(tw)):
            ld.text((xx, yy), text, font=f, fill=(200, 40, 40, 60))
    layer = layer.rotate(25, resample=Image.BICUBIC)
    base = d._image
    base.alpha_composite(layer.crop((W//2, H//2, W//2+W, H//2+H)))
    # 모서리 고정 표기(불투명, 작게) — 축소 삽화에서도 식별
    d.text((30, H-36), "見本・架空・本人確認に使用不可", font=F(18, True), fill=(200,40,40,255))
def label_val(d, x, y, label, val, lw=120, fs=20, boxes=None, key=None):
    d.text((x, y), label, font=F(fs-4), fill=(90,90,90))
    d.text((x+lw, y), val, font=F(fs), fill=(20,20,20))
    bb = d.textbbox((x+lw, y), val, font=F(fs))
    if boxes is not None and key: boxes[key] = [bb[0]-4, bb[1]-4, bb[2]+4, bb[3]+4]
    return bb
def finalize(img, path_base, boxes, meta):
    os.makedirs(os.path.dirname(path_base), exist_ok=True)
    W, H = img.size
    img.convert("RGB").save(path_base + ".png")                       # 스캔풍
    photo = img.convert("RGB").rotate(random.uniform(-3, 3), expand=True, fillcolor=(235,230,220))
    photo = photo.filter(ImageFilter.GaussianBlur(0.6))
    sh = Image.new("RGB", photo.size, (0,0,0)); photo = Image.blend(photo, sh, 0.06)
    photo.save(path_base + ".jpg", quality=82)                        # 촬영풍 (회전·흐림·어두움)
    c = canvas.Canvas(path_base + ".pdf", pagesize=(W*0.5, H*0.5)); c.drawImage(path_base + ".png", 0, 0, W*0.5, H*0.5); c.save()
    spec = {"file": os.path.basename(path_base), "size": [W, H], "boxes_png": boxes, **meta,
            "note": "jpg는 회전·흐림 적용으로 박스 좌표 불일치 → 탐지는 OCR 좌표로 재계산, png/pdf 좌표만 골든 비교"}
    json.dump(spec, open(path_base + ".specs.json", "w"), ensure_ascii=False, indent=1)

# ---------- 1. 資格確認書 (카드형, 보험자 3종 변형) ----------
def shikaku(variant):
    W, H = 1100, 700; img = Image.new("RGBA", (W, H), (248, 248, 244, 255)); d = ImageDraw.Draw(img)
    d.rectangle([20,20,W-20,H-20], outline=(120,120,120), width=3)
    title = {"kenpo":"資格確認書（被用者保険・架空）", "kokuho":"国民健康保険 資格確認書（架空）", "kouki":"後期高齢者医療 資格確認書（架空）"}[variant]
    d.text((40, 40), title, font=F(30, True), fill=(30,30,30))
    boxes = {}; n = name(); mn = mynumber_invalid()
    y = 110
    if variant == "kouki":
        label_val(d, 40, y, "被保険者番号", "9999" + str(random.randint(1000,9999)), 200, 26, boxes, "hihokensha_bango"); y += 50
    else:
        label_val(d, 40, y, "記号", str(random.randint(90000000,99999999)), 120, 26, boxes, "kigo")
        label_val(d, 420, y, "番号", str(random.randint(900,999)), 100, 26, boxes, "bango")
        label_val(d, 700, y, "枝番", f"{random.randint(0,99):02d}", 100, 26, boxes, "edaban"); y += 50
    label_val(d, 40, y, "氏名", n, 120, 28, boxes, "name"); y += 48
    label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth")
    label_val(d, 520, y, "性別", random.choice(["男","女"]), 80, 24, boxes, "sex"); y += 46
    label_val(d, 40, y, "住所", addr(), 120, 22, boxes, "address"); y += 46
    label_val(d, 40, y, "資格取得年月日", "令和7年4月1日", 220, 22, boxes, "shikaku_date")
    label_val(d, 520, y, "有効期限", "令和12年3月31日", 140, 22, boxes, "expiry"); y += 46
    if variant == "kenpo":
        label_val(d, 40, y, "事業所名称", "架空株式会社", 160, 22, boxes, "jigyosho"); y += 46
    label_val(d, 40, y, "保険者番号", hokensha(), 160, 26, boxes, "hokensha_bango")
    label_val(d, 520, y, "保険者名", {"kenpo":"架空健康保険協会","kokuho":"見本市","kouki":"架空県後期高齢者医療広域連合"}[variant], 140, 20, boxes, "hokensha_name"); y += 50
    # 二次元コード 자리: 실제 QR 대신 "二次元コード欄(模擬)" 회색 박스 — 판독 불가
    d.rectangle([W-220, H-220, W-60, H-60], fill=(200,200,200), outline=(120,120,120)); d.text((W-212, H-150), "二次元コード欄\n(模擬・判読不可)", font=F(16), fill=(80,80,80))
    boxes["qr"] = [W-220, H-220, W-60, H-60]
    mihon(d, W, H)
    purposes = {
        "本人確認提出": {"mask": ["hokensha_bango","kigo","bango","edaban","hihokensha_bango","qr"], "recommend": ["sex"], "keep": ["name","birth","address","expiry","jigyosho"],
                     "legal_basis": "健康保険法 告知要求制限 (2020-10-01). QRは番号判読可能なため同一扱い", "source": "https://www.mhlw.go.jp/stf/newpage_13989.html"},
        "医療機関提示": {"mask": [], "keep": "all", "legal_basis": "医療保険事務は告知要求制限の対象外"}}
    finalize(img, f"{OUT}/shikaku_kakuninsho/{variant}", {k:v for k,v in boxes.items()}, {"doc":"資格確認書","variant":variant,"purposes":purposes})

# ---------- 2. 運転免許証 (앞·뒤, 도식형) ----------
def license_card(side):
    W, H = 1100, 700; img = Image.new("RGBA", (W, H), (244, 247, 244, 255)); d = ImageDraw.Draw(img)
    d.rectangle([20,20,W-20,H-20], outline=(120,120,120), width=3); boxes = {}
    if side == "front":
        d.text((40, 40), "運転免許証（架空・図式）", font=F(30, True), fill=(30,30,30))
        d.rectangle([W-300, 100, W-80, 380], fill=(210,215,220), outline=(120,120,120)); d.text((W-280, 220), "顔写真欄\n(シルエット)", font=F(18), fill=(70,70,70)); boxes["photo"]=[W-300,100,W-80,380]
        n = name(); y = 110
        label_val(d, 40, y, "氏名", n, 120, 28, boxes, "name"); y += 50
        label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth"); y += 46
        label_val(d, 40, y, "住所", addr(), 120, 22, boxes, "address"); y += 46
        label_val(d, 40, y, "交付", "令和6年5月10日", 120, 22, boxes, "issue"); y += 46
        label_val(d, 40, y, "有効期限", "令和11年6月30日まで有効", 160, 22, boxes, "expiry"); y += 46
        label_val(d, 40, y, "番号", "第 " + license_no() + " 号", 120, 26, boxes, "license_no"); y += 50
        label_val(d, 40, y, "種類", "普通 / 原付", 120, 22, boxes, "types")
        d.text((40, H-80), "（公安委員会名・公印・IC表示は意図的に省略）", font=F(16), fill=(120,120,120))
        purposes = {"本人確認提出": {"mask": [], "optional": ["license_no"], "keep": ["name","birth","address","expiry","photo"], "legal_basis": "提出先指示優先。番号マスキングは任意（KYCで必須とする提出先あり）"}}
    else:
        d.text((40, 40), "運転免許証 裏面（架空・図式）", font=F(30, True), fill=(30,30,30))
        d.text((40, 110), "備考欄（住所・氏名等の変更記載）", font=F(22), fill=(90,90,90))
        d.rectangle([40, 145, W-40, 330], outline=(120,120,120));
        d.text((60, 160), "令和7年1月15日 住所変更  " + addr(), font=F(22), fill=(20,20,20)); boxes["biko_change"] = [40,145,W-40,330]
        d.text((40, 360), "臓器提供意思表示欄（任意記載・模擬）", font=F(22), fill=(90,90,90))
        d.rectangle([40, 395, W-40, 560], outline=(120,120,120)); d.text((60, 410), "1. 脳死後・心停止後のいずれでも提供します（模擬）", font=F(20), fill=(20,20,20)); boxes["organ_donor"] = [40,395,W-40,560]
        purposes = {"本人確認提出": {"mask": ["biko_change","organ_donor"], "keep": [], "legal_basis": "裏面変更記載は旧住所等の不要情報、臓器提供欄は要配慮情報に準ずる（SoftBank等の提出先指示）", "source": "https://tm.softbank.jp/content/dam/common/services/dialpad/pdf/cidn-dialpad-online-identification.pdf"}}
    mihon(d, W, H)
    finalize(img, f"{OUT}/unten_menkyo/{side}", boxes, {"doc":"運転免許証","variant":side,"purposes":purposes})

# ---------- 3. マイナンバーカード (앞·뒤, 도식형) ----------
def mynumber_card(side):
    W, H = 1100, 700; img = Image.new("RGBA", (W, H), (246, 244, 250, 255)); d = ImageDraw.Draw(img)
    d.rectangle([20,20,W-20,H-20], outline=(120,120,120), width=3); boxes = {}
    if side == "front":
        d.text((40, 40), "個人番号カード 表面（架空・図式）", font=F(30, True), fill=(30,30,30))
        d.rectangle([W-300, 100, W-80, 380], fill=(210,215,220), outline=(120,120,120)); d.text((W-280, 220), "顔写真欄\n(シルエット)", font=F(18), fill=(70,70,70)); boxes["photo"]=[W-300,100,W-80,380]
        n = name(); y = 110
        label_val(d, 40, y, "氏名", n, 120, 28, boxes, "name"); y += 50
        label_val(d, 40, y, "住所", addr(), 120, 22, boxes, "address"); y += 46
        label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth")
        label_val(d, 560, y, "性別", random.choice(["男","女"]), 80, 24, boxes, "sex"); y += 46
        label_val(d, 40, y, "有効期限", "2035年3月31日まで有効", 160, 22, boxes, "expiry"); y += 46
        d.text((40, y), "臓器提供意思表示欄（模擬）", font=F(18), fill=(90,90,90)); d.rectangle([40, y+30, W-340, y+120], outline=(120,120,120)); boxes["organ_donor"]=[40,y+30,W-340,y+120]
        purposes = {"身元確認": {"mask": [], "recommend": ["sex","organ_donor"], "keep": ["name","address","birth","expiry","photo"], "legal_basis": "表面は本人同意で複写可（PPC FAQ）", "source": "https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"}}
    else:
        d.text((40, 40), "個人番号カード 裏面（架空・図式）", font=F(30, True), fill=(30,30,30))
        y = 130
        label_val(d, 40, y, "個人番号", " ".join([mynumber_invalid()[i:i+4] for i in (0,4,8)]), 160, 34, boxes, "my_number"); y += 70
        label_val(d, 40, y, "氏名", name(), 120, 26, boxes, "name"); y += 50
        label_val(d, 40, y, "生年月日", wareki(), 160, 24, boxes, "birth"); y += 50
        d.rectangle([W-220, H-220, W-60, H-60], fill=(200,200,200), outline=(120,120,120)); d.text((W-212, H-150), "二次元コード欄\n(模擬・判読不可)", font=F(16), fill=(80,80,80)); boxes["qr"]=[W-220,H-220,W-60,H-60]
        d.text((40, H-80), "（裏面の生年月日有無は公式見本で要確認 — 未確認項目）", font=F(16), fill=(120,120,120))
        purposes = {"身元確認": {"mask": ["ALL"], "legal_basis": "番号法: 法定目的以外の個人番号の複写・保管禁止 → 身元確認では裏面を提出しない", "source": "https://www.ppc.go.jp/all_faq_index/faq5-q6-12/"},
                    "個人番号手続": {"mask": [], "keep": ["my_number","name","birth"], "legal_basis": "税・社会保障等の個人番号関係事務では裏面提出が必要"}}
    mihon(d, W, H)
    finalize(img, f"{OUT}/mynumber_card/{side}", boxes, {"doc":"マイナンバーカード","variant":side,"purposes":purposes})

# ---------- 4. 住民票の写し (A4 PDF + PNG, 변형 4) ----------
def juminhyo(variant):
    # variant: zenin_mynumber / ichibu_plain / honseki_on / gaikokujin
    W, H = 1240, 1754; img = Image.new("RGBA", (W, H), (255,255,255,255)); d = ImageDraw.Draw(img); boxes = {}
    d.text((W/2-120, 70), "住 民 票（架空・図式）", font=F(40, True), fill=(20,20,20))
    d.text((W-420, 130), "発行日 令和8年10月21日", font=F(22), fill=(20,20,20))
    y = 200; members = 3 if variant == "zenin_mynumber" else 1
    label_val(d, 80, y, "住所", addr(), 140, 26, boxes, "address"); y += 60
    head = name()
    label_val(d, 80, y, "世帯主", head, 140, 26, boxes, "setainushi"); y += 70
    for i in range(members):
        d.line([80, y-10, W-80, y-10], fill=(150,150,150), width=2)
        n = head if i == 0 else name(); k = f"m{i+1}_"
        label_val(d, 80, y, "氏名", n, 140, 28, boxes, k+"name"); label_val(d, 700, y, "続柄", ["本人","妻","子"][i], 100, 24, boxes, k+"zokugara"); y += 50
        label_val(d, 80, y, "生年月日", wareki(), 160, 24, boxes, k+"birth"); label_val(d, 700, y, "性別", random.choice(["男","女"]), 100, 24, boxes, k+"sex"); y += 50
        label_val(d, 80, y, "住民となった日", "平成30年4月1日", 220, 22, boxes, k+"since"); y += 50
        if variant in ("honseki_on", "zenin_mynumber"):
            label_val(d, 80, y, "本籍", addr(), 140, 22, boxes, k+"honseki"); y += 46
            label_val(d, 80, y, "筆頭者", n, 140, 22, boxes, k+"hittosha"); y += 46
        if variant == "zenin_mynumber":
            label_val(d, 80, y, "個人番号", mynumber_invalid(), 160, 26, boxes, k+"my_number"); y += 50
        if variant == "gaikokujin":
            label_val(d, 80, y, "国籍・地域", "架空国", 160, 22, boxes, k+"kokuseki"); y += 46
            label_val(d, 80, y, "在留資格", "技術・人文知識・国際業務", 160, 22, boxes, k+"zairyu_shikaku"); y += 46
            label_val(d, 80, y, "在留期間", "5年（2030年3月31日まで）", 160, 22, boxes, k+"zairyu_kikan"); y += 46
            label_val(d, 80, y, "在留カード番号", "ZZ99999999ZZ", 220, 22, boxes, k+"zairyu_no"); y += 46
        y += 30
    if variant == "zenin_mynumber":
        label_val(d, 80, y, "住民票コード", "99999999999", 180, 24, boxes, "jumin_code"); y += 50
    d.text((80, y+20), "この写しは、世帯全員（または一部）の住民票の原本と相違ないことを証明します。（架空）", font=F(20), fill=(60,60,60))
    d.text((W-480, y+80), "見本市長 架空 太郎（公印省略・模擬）", font=F(22), fill=(60,60,60)); boxes["mayor"]=[W-480,y+70,W-80,y+115]
    mihon(d, W, H, "見本・架空 / 証明書として無効")
    purposes = {
        "本人確認提出": {"mask": [k for k in boxes if k.endswith("my_number") or k=="jumin_code"], "recommend": [k for k in boxes if "honseki" in k or "hittosha" in k or k.startswith("m2_") or k.startswith("m3_")],
                     "keep": ["address","m1_name","m1_birth"], "legal_basis": "個人番号は番号法で収集制限／本籍・他世帯員は提出先指示で不要が多い", "source": "https://www.pref.osaka.lg.jp/documents/135080/6tempujichui.pdf"},
        "個人番号手続": {"mask": [k for k in boxes if "honseki" in k], "keep": [k for k in boxes if k.endswith("my_number")], "legal_basis": "個人番号記載が目的の提出"}}
    finalize(img, f"{OUT}/juminhyo/{variant}", boxes, {"doc":"住民票の写し","variant":variant,"purposes":purposes})

if __name__ == "__main__":
    for v in ("kenpo","kokuho","kouki"): shikaku(v)
    for s in ("front","back"): license_card(s); mynumber_card(s)
    for v in ("zenin_mynumber","ichibu_plain","honseki_on","gaikokujin"): juminhyo(v)
    n = sum(len(f) for _,_,f in os.walk(OUT)); print("files:", n)
