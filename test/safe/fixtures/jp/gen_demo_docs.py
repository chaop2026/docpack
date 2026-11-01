#!/usr/bin/env python3
"""
SafeFile JP — デモ用ダミー書類ジェネレータ(S10, 2026-11-01)

  python3 test/safe/fixtures/jp/gen_demo_docs.py          # 全部
  python3 test/safe/fixtures/jp/gen_demo_docs.py keiyakusho gensen

── これは何で、何ではないか ────────────────────────────────────────────────

これは **デモ用の小道具** を作る。Shorts の録画・ブログのスクリーンショット・ガイド PDF に
映すための、実在しない書類である。

**検出テストのフィクスチャではない。** `gen.py` が作る 4 種(資格確認書・運転免許証・
マイナンバーカード・住民票)はゴールデンハーネスの入力で、期待マスキング座標 `*.specs.json`
を持ち、`JP_RULES`・`check_matrix` と結びついている。ここで作るものは **specs を持たない** —
マーケティング計画 0-5 のとおり、4 種以外は「手動で範囲を選択」してデモする。

したがって:
  * `out/` ではなく各 `<doc>/` に直接書く(gen.py の出力先と混ざらない)
  * `*.specs.json` を **作らない**
  * 既存 4 種のディレクトリには **一切触れない**
  * ゴールデン 557 と check_matrix 188 triple は **不変でなければならない**

── なぜ gen.py を使わないのか ──────────────────────────────────────────────

`gen.py` は Linux + Noto CJK 前提(`/usr/share/fonts/opentype/noto/...`)で、この Mac では
動かない。そして CLAUDE.md S3 が記録しているとおり、**既存 4 種を再生成すると PIL の
バージョン差で箱の座標が動き、spec が全部壊れる。** 別ファイルにしてあるのはそのためで、
この二つは今後も混ぜない。

── 安全条件(戦略 v2 §4 を承継) ───────────────────────────────────────────

実物の縦横比・色・書体・欄配置を同時に再現しない(**欄位置のワイヤフレーム**として描く) /
全面に「見本・架空」の透かし / ロゴ・官印・QR・IC 表示なし / 番号は規格を満たさない /
実在しない住所(99丁目) / 架空の人名 / 顔写真は灰色の空パネル。

⚠️ この저장소は **公開** である(CLAUDE.md JP-1 이슈 로그 2026-10-21 の決定)。
「오용 가치 0」とは書かない — 低いが 0 ではない。**日本の弁護士レビューは依然として無い。**
"""
import json, os, random, sys

from PIL import Image, ImageDraw, ImageFont

# 決定的。seed を変えると全部のダミーが変わる。
random.seed(20261101)

HERE = os.path.dirname(os.path.abspath(__file__))

# ── フォント解決 ───────────────────────────────────────────────────────────
# 候補から順に探す。「この Mac でしか動かないジェネレータ」をもう一つ作らない —
# gen.py が Linux 専用で詰んだのがまさにそれだった。見つからなければ **明示的に落ちる**。
FONT_CANDIDATES = [
    # Linux (CI / Docker)
    ("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc", 0),
    ("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", 0),
    ("/usr/share/fonts/truetype/fonts-japanese-gothic.ttf", 0),
    # macOS
    ("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 0),
    ("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 0),
    ("/System/Library/Fonts/Hiragino Sans GB.ttc", 0),
]


def _resolve():
    reg = bold = None
    for path, idx in FONT_CANDIDATES:
        if not os.path.exists(path):
            continue
        try:
            ImageFont.truetype(path, 16, index=idx)
        except OSError:
            continue
        low = path.lower()
        if ("bold" in low or "w6" in low) and bold is None:
            bold = (path, idx)
        elif reg is None:
            reg = (path, idx)
    if reg is None:
        raise SystemExit(
            "no CJK font found. Tried:\n  " + "\n  ".join(p for p, _ in FONT_CANDIDATES)
            + "\nInstall fonts-noto-cjk (Linux) or run on macOS."
        )
    return reg, (bold or reg)


REG, BOLD = _resolve()


def F(size, bold=False):
    path, idx = BOLD if bold else REG
    return ImageFont.truetype(path, size, index=idx)


# ── 架空データ ────────────────────────────────────────────────────────────
SURN = ["架空", "見本", "仮名", "試験", "例示", "模擬"]
GIVEN = ["太郎", "花子", "一郎", "美咲", "健太", "さくら"]
PREF = ["東京都", "大阪府", "神奈川県", "愛知県", "福岡県"]
CITY = {"東京都": "架空区", "大阪府": "見本市", "神奈川県": "仮名市", "愛知県": "試験市", "福岡県": "例示市"}


def name():
    return random.choice(SURN) + " " + random.choice(GIVEN)


def addr():
    p = random.choice(PREF)
    return f"{p}{CITY[p]}架空町{random.randint(90,99)}丁目{random.randint(90,99)}番{random.randint(90,99)}号"


def wareki():
    return f"昭和{random.randint(40,63)}年{random.randint(1,12)}月{random.randint(1,28)}日"


def digits(n):
    return "".join(str(random.randint(0, 9)) for _ in range(n))


def mynumber_invalid():
    """12桁。チェックデジットを意図的に外す(gen.py と同じ方針)。"""
    d = [random.randint(0, 9) for _ in range(11)]
    s = 0
    for n in range(1, 12):
        p = d[11 - n]
        q = n + 1 if n <= 6 else n - 5
        s += p * q
    chk = 11 - (s % 11)
    chk = 0 if chk >= 10 else chk
    return "".join(map(str, d)) + str((chk + 1) % 10)


# ── 描画部品 ──────────────────────────────────────────────────────────────
PAPER = (247, 245, 239)
INK = (23, 20, 15)
SUB = (107, 101, 90)
LINE = (205, 199, 185)
RED = (163, 45, 45)


def mihon(img, text="見本・架空 / 実在しません"):
    """全面の透かし。縮小しても残るよう、角にも不透明の印を置く。"""
    W, H = img.size
    layer = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = F(max(22, W // 26))
    step = max(150, W // 5)
    for y in range(0, H * 2, step):
        for x in range(0, W * 2, step * 3):
            d.text((x, y), text, font=f, fill=(190, 60, 60, 70))
    layer = layer.rotate(30, resample=Image.BICUBIC, center=(W, H))
    img.alpha_composite(layer, (-W // 2, -H // 2))

    d2 = ImageDraw.Draw(img)
    f2 = F(max(13, W // 52), bold=True)
    d2.text((14, H - max(26, W // 40)), "見本・架空 — 本人確認・提出に使用不可", font=f2, fill=(190, 60, 60, 255))


def frame(W, H, title):
    img = Image.new("RGBA", (W, H), PAPER + (255,))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 8, W - 9, H - 9], outline=LINE, width=3)
    d.text((34, 30), title, font=F(max(20, W // 30), bold=True), fill=INK)
    d.line([(34, 30 + max(20, W // 30) + 14), (W - 34, 30 + max(20, W // 30) + 14)], fill=LINE, width=2)
    return img, d


def row(d, x, y, label, value, lw=190, fs=19, boxed=False, W=None):
    """ラベル → 値。boxed=True は『ここが隠す対象』の枠(デモで指差す場所)。"""
    d.text((x, y), label, font=F(int(fs * 0.82)), fill=SUB)
    vx = x + lw
    d.text((vx, y - 2), value, font=F(fs), fill=INK)
    if boxed:
        w = d.textlength(value, font=F(fs))
        d.rectangle([vx - 7, y - 8, vx + w + 7, y + fs + 8], outline=RED, width=2)
    return y + fs + 20


def save(img, doc, variant):
    out = os.path.join(HERE, doc)
    os.makedirs(out, exist_ok=True)
    rgb = img.convert("RGB")
    png = os.path.join(out, f"{variant}.png")
    jpg = os.path.join(out, f"{variant}.jpg")
    rgb.save(png)
    # 撮影風の JPG。OCR 経路のデモに使うので、わざと少しだけ品質を落とす。
    rgb.save(jpg, quality=82)
    print(f"  {doc}/{variant}.png  {rgb.size[0]}x{rgb.size[1]}")
    return png


# ── 8 種 ──────────────────────────────────────────────────────────────────
def keiyakusho(_v):
    """賃貸借契約書(ep03·ep04) — 条項は残し、相手方の情報を隠す。"""
    W, H = 1240, 1754
    img, d = frame(W, H, "建物賃貸借契約書（架空・見本）")
    y = 130
    y = row(d, 60, y, "貸主（甲）", name(), boxed=True)
    y = row(d, 60, y, "貸主住所", addr(), boxed=True)
    y = row(d, 60, y, "借主（乙）", name(), boxed=True)
    y = row(d, 60, y, "連帯保証人", name(), boxed=True)
    y = row(d, 60, y, "保証人電話", f"090-{digits(4)}-{digits(4)}", boxed=True)
    y += 18
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 26
    for head, body in [
        ("第3条（賃料）", "賃料は月額 128,000 円とし、毎月末日までに翌月分を支払う。"),
        ("第4条（更新料）", "更新の際、借主は賃料の1か月分を更新料として支払う。"),
        ("第8条（原状回復）", "通常損耗および経年変化は借主の負担としない。"),
    ]:
        d.text((60, y), head, font=F(21, bold=True), fill=INK)
        y += 32
        d.text((76, y), body, font=F(19), fill=INK)
        y += 40
    y += 14
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 26
    y = row(d, 60, y, "振込先", "架空銀行 見本支店", boxed=True)
    y = row(d, 60, y, "口座番号", digits(7), boxed=True)
    mihon(img)
    return save(img, "keiyakusho", "chintai")


def gensen(_v):
    """源泉徴収票(ep07) — 個人番号が印字されている版。"""
    W, H = 1400, 900
    img, d = frame(W, H, "令和7年分 給与所得の源泉徴収票（架空・見本）")
    y = 120
    y = row(d, 60, y, "支払を受ける者 住所", addr(), lw=250)
    y = row(d, 60, y, "氏名", name(), lw=250)
    y = row(d, 60, y, "個人番号", mynumber_invalid(), lw=250, boxed=True)
    y += 16
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 26
    for lab, val in [("支払金額", "4,820,000 円"), ("給与所得控除後の金額", "3,356,000 円"),
                     ("所得控除の額の合計額", "1,180,000 円"), ("源泉徴収税額", "98,400 円")]:
        y = row(d, 60, y, lab, val, lw=300)
    y += 16
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 26
    y = row(d, 60, y, "支払者 名称", "架空株式会社", lw=250)
    y = row(d, 60, y, "支払者 法人番号", digits(13), lw=250, boxed=True)
    mihon(img)
    return save(img, "gensen_choshuhyo", "mynumber_on")


def rirekisho(_v):
    """履歴書(ep18 想定) — AI に貼る前に消すもの。"""
    W, H = 1240, 1754
    img, d = frame(W, H, "履歴書（架空・見本）")
    y = 130
    y = row(d, 60, y, "ふりがな", "かくう たろう", boxed=True)
    y = row(d, 60, y, "氏名", name(), boxed=True)
    y = row(d, 60, y, "生年月日", wareki(), boxed=True)
    y = row(d, 60, y, "現住所", addr(), boxed=True)
    y = row(d, 60, y, "電話", f"090-{digits(4)}-{digits(4)}", boxed=True)
    y = row(d, 60, y, "メール", "mihon@example.invalid", boxed=True)
    # 顔写真は灰色の空パネル(戦略 v2 §4: 写真を置かない)
    d.rectangle([W - 300, 120, W - 80, 420], outline=LINE, width=3, fill=(224, 220, 211))
    d.text((W - 268, 258), "写真なし", font=F(21), fill=SUB)
    y += 20
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 24
    d.text((60, y), "学歴・職歴", font=F(22, bold=True), fill=INK)
    y += 38
    for t in ["平成30年3月　架空大学 見本学部 卒業", "平成30年4月　架空株式会社 入社",
              "令和4年6月　同社 開発部 異動", "令和7年3月　一身上の都合により退職"]:
        d.text((76, y), t, font=F(19), fill=INK)
        y += 34
    mihon(img)
    return save(img, "rirekisho", "plain")


def kyuyo(_v):
    """給与明細(ep19 想定)。"""
    W, H = 1400, 900
    img, d = frame(W, H, "給与支払明細書 令和7年10月分（架空・見本）")
    y = 120
    y = row(d, 60, y, "氏名", name(), lw=220, boxed=True)
    y = row(d, 60, y, "社員番号", digits(6), lw=220, boxed=True)
    y = row(d, 60, y, "所属", "架空株式会社 開発部", lw=220)
    y += 16
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 26
    left = y
    for lab, val in [("基本給", "320,000"), ("時間外手当", "42,500"), ("通勤手当", "12,000")]:
        y = row(d, 60, y, lab, val, lw=220)
    y = left
    for lab, val in [("健康保険", "16,400"), ("厚生年金", "29,280"), ("所得税", "8,120")]:
        y = row(d, 760, y, lab, val, lw=200)
    y += 20
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 26
    y = row(d, 60, y, "差引支給額", "320,700 円", lw=220)
    y = row(d, 60, y, "振込口座", f"架空銀行 見本支店 普通 {digits(7)}", lw=220, boxed=True)
    mihon(img)
    return save(img, "kyuyo_meisai", "plain")


def tsucho(_v):
    """通帳の見開き(ep20 想定)。"""
    W, H = 1400, 760
    img, d = frame(W, H, "普通預金通帳（架空・見本）")
    y = 118
    y = row(d, 60, y, "店番", digits(3), lw=180, boxed=True)
    y = row(d, 60, y, "口座番号", digits(7), lw=180, boxed=True)
    y = row(d, 60, y, "お名前", name() + " 様", lw=180, boxed=True)
    y += 14
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 22
    cols = [("年月日", 60), ("摘要", 260), ("お支払金額", 620), ("お預り金額", 860), ("差引残高", 1120)]
    for t, x in cols:
        d.text((x, y), t, font=F(17, bold=True), fill=SUB)
    y += 30
    for date, memo, out_, in_, bal in [
        ("07-09-25", "キユウヨ", "", "320,700", "612,480"),
        ("07-10-01", "カ)カクウフドウサン", "128,000", "", "484,480"),
        ("07-10-05", "デンキ", "9,840", "", "474,640"),
    ]:
        d.text((60, y), date, font=F(18), fill=INK)
        d.text((260, y), memo, font=F(18), fill=INK)
        d.text((620, y), out_, font=F(18), fill=INK)
        d.text((860, y), in_, font=F(18), fill=INK)
        d.text((1120, y), bal, font=F(18), fill=INK)
        y += 32
    mihon(img)
    return save(img, "tsucho", "spread")


def zairyu(_v):
    """在留カード(ep21 想定) — 欄位置のワイヤフレーム。"""
    W, H = 1016, 640
    img, d = frame(W, H, "在留カード（架空・見本）")
    y = 118
    y = row(d, 50, y, "氏名 / NAME", "MIHON KAKUU", lw=210, boxed=True)
    y = row(d, 50, y, "生年月日", wareki(), lw=210, boxed=True)
    y = row(d, 50, y, "国籍・地域", "架空国", lw=210)
    y = row(d, 50, y, "住居地", addr(), lw=210, boxed=True)
    y = row(d, 50, y, "在留資格", "技術・人文知識・国際業務", lw=210)
    y = row(d, 50, y, "在留期間", "5年（令和12年3月31日まで）", lw=210)
    # 番号は規格外(末尾を数字にして英字2文字+8桁の形を崩す)
    y = row(d, 50, y, "番号", "ZZ" + digits(8) + "9", lw=210, boxed=True)
    d.rectangle([W - 230, 120, W - 60, 340], outline=LINE, width=3, fill=(224, 220, 211))
    d.text((W - 200, 218), "写真なし", font=F(19), fill=SUB)
    mihon(img)
    return save(img, "zairyu_card", "front")


def passport(_v):
    """パスポートの身分事項ページ(ep22 想定)。MRZ は意図的に不正。"""
    W, H = 1240, 880
    img, d = frame(W, H, "旅券 身分事項ページ（架空・見本）")
    y = 125
    y = row(d, 55, y, "型 / Type", "P", lw=230)
    y = row(d, 55, y, "旅券番号 / No.", "ZZ" + digits(6) + "9", lw=230, boxed=True)
    y = row(d, 55, y, "姓 / Surname", "MIHON", lw=230, boxed=True)
    y = row(d, 55, y, "名 / Given name", "KAKUU", lw=230, boxed=True)
    y = row(d, 55, y, "生年月日 / DOB", wareki(), lw=230, boxed=True)
    y = row(d, 55, y, "本籍 / Registered", random.choice(PREF), lw=230, boxed=True)
    y = row(d, 55, y, "発行年月日", "令和7年4月1日", lw=230)
    d.rectangle([W - 300, 125, W - 70, 430], outline=LINE, width=3, fill=(224, 220, 211))
    d.text((W - 262, 268), "写真なし", font=F(20), fill=SUB)
    # MRZ 風の帯。チェックディジットが合わない文字列にしてある。
    mrz_y = H - 150
    d.rectangle([40, mrz_y - 12, W - 40, mrz_y + 76], outline=LINE, width=2, fill=(238, 235, 228))
    d.text((56, mrz_y), "P<ZZZMIHON<<KAKUU<<<<<<<<<<<<<<<<<<<<<<<<<<<<", font=F(22), fill=INK)
    d.text((56, mrz_y + 36), "ZZ" + digits(6) + "9ZZZ9901019M3503319<<<<<<<<<<<<<<9", font=F(22), fill=INK)
    mihon(img)
    return save(img, "passport", "data_page")


def shokumu(_v):
    """職務経歴書(ep23 想定) — 本文は残し、固有名詞を隠す。"""
    W, H = 1240, 1754
    img, d = frame(W, H, "職務経歴書（架空・見本）")
    y = 130
    y = row(d, 60, y, "氏名", name(), boxed=True)
    y = row(d, 60, y, "連絡先", "mihon@example.invalid", boxed=True)
    y += 18
    d.line([(60, y), (W - 60, y)], fill=LINE, width=2)
    y += 26
    for head, lines in [
        ("架空株式会社（令和元年4月〜令和7年3月）", [
            "・社内業務システムの設計・実装（利用者 約300名）",
            "・requirements のヒアリングから運用まで一貫して担当",
            "・チーム4名のリード、コードレビュー体制の整備"]),
        ("見本テクノロジー株式会社（平成28年4月〜平成31年3月）", [
            "・受託開発のバックエンド実装",
            "・月次のリリース作業と障害一次対応"]),
    ]:
        d.text((60, y), head, font=F(21, bold=True), fill=INK)
        y += 34
        for t in lines:
            d.text((76, y), t, font=F(19), fill=INK)
            y += 32
        y += 14
    mihon(img)
    return save(img, "shokumu_keirekisho", "plain")


DOCS = {
    "keiyakusho": keiyakusho,
    "gensen": gensen,
    "rirekisho": rirekisho,
    "kyuyo": kyuyo,
    "tsucho": tsucho,
    "zairyu": zairyu,
    "passport": passport,
    "shokumu": shokumu,
}

# 既存 4 種。触らないことを機械的に保証する。
PROTECTED = {"shikaku_kakuninsho", "unten_menkyo", "mynumber_card", "juminhyo"}


def main():
    want = sys.argv[1:] or list(DOCS)
    unknown = [w for w in want if w not in DOCS]
    if unknown:
        raise SystemExit(f"unknown doc(s): {', '.join(unknown)}\nknown: {', '.join(DOCS)}")

    before = {p: sorted(os.listdir(os.path.join(HERE, p))) for p in PROTECTED
              if os.path.isdir(os.path.join(HERE, p))}

    print(f"font: {REG[0]}")
    made = [DOCS[w](None) for w in want]

    # 既存 4 種に一文字も触っていないことを確認してから終わる。specs の座標が動くと
    # ゴールデン 557 が全部壊れる — それが gen.py と分けてある理由そのものである。
    after = {p: sorted(os.listdir(os.path.join(HERE, p))) for p in before}
    if before != after:
        raise SystemExit("REFUSING: the protected alpha fixtures changed. "
                         f"before={before} after={after}")
    print(f"\n{len(made)} demo document(s) written. "
          "No specs.json — these are props, not detection fixtures.")


if __name__ == "__main__":
    main()
