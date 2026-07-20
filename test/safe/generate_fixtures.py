#!/usr/bin/env python3
"""
Golden-fixture generator for the SafeFile PII pipeline.

Produces synthetic test documents into ./testdocs (git-ignored). NO real
personal data is committed — every value below is fabricated to exercise a
specific detection trap. The paired specs live in ./specs.json.

Docs:
  1_text.pdf        Korean cert, real text layer
  2_scanned.pdf     image-only page (OCR path)
  3_photo.jpg       photo with text (OCR path)
  4_table.pdf       table-heavy PDF
  5_multipage.pdf   3-page PDF
  6_resume_light.pdf  Indian resume, single light column (large name, schools, phone)
  7_resume_dark.pdf   Indian resume, 2-column LIGHT-left / DARK-green-right,
                      reproducing every trap from the real document.
"""
import fitz, os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "testdocs")
os.makedirs(OUT, exist_ok=True)
KFONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"


# ─────────────── base doc 1: Korean text PDF ───────────────
def text_pdf():
    doc = fitz.open(); page = doc.new_page(width=595, height=842)
    page.insert_font(fontname="F0", fontfile=KFONT)
    lines = [
        ("재직증명서", 22), ("", 8),
        ("성명: 김민준", 13),
        ("주민등록번호: 900315-1234567", 13),
        ("생년월일: 1990년 3월 15일", 13),
        ("주소: 서울특별시 강남구 테헤란로 152, 1204호", 13),
        ("연락처: 010-2345-6789", 13),
        ("이메일: minjun.kim@hanmail.net", 13), ("", 8),
        ("위 사람은 주식회사 한빛테크 개발팀에서 2019년 4월 1일부터", 12),
        ("현재까지 선임연구원으로 재직 중임을 증명합니다.", 12), ("", 8),
        ("급여계좌: 국민은행 123456-04-789012", 13),
        ("비상연락망: 김서연 (배우자) 010-9876-5432", 13), ("", 12),
        ("2026년 7월 15일", 12),
        ("주식회사 한빛테크 대표이사 박정호", 13),
    ]
    y = 70
    for txt, sz in lines:
        if txt:
            page.insert_text((60, y), txt, fontname="F0", fontsize=sz, color=(0.09, 0.08, 0.06))
        y += sz + 12
    doc.save(os.path.join(OUT, "1_text.pdf")); print("1_text.pdf")


def doc_image(lines, w=900, h=1180, table=False):
    img = Image.new("RGB", (w, h), "white"); d = ImageDraw.Draw(img)
    F = lambda sz: ImageFont.truetype(KFONT, sz)
    y = 70
    for txt, sz in lines:
        if txt:
            d.text((60, y), txt, font=F(sz), fill=(20, 18, 12))
        y += sz + 18
    if table:
        tx, ty, tw = 60, y + 20, w - 120
        rows = [["항목", "내용"], ["성명", "이대호"], ["연락처", "010-3456-7890"],
                ["계좌번호", "110-234-567890"], ["이메일", "daeho.lee@company.co.kr"]]
        rh = 46
        for i, row in enumerate(rows):
            ry = ty + i * rh
            d.rectangle([tx, ry, tx + tw, ry + rh], outline=(60, 60, 60), width=2)
            d.line([tx + 180, ry, tx + 180, ry + rh], fill=(60, 60, 60), width=2)
            d.text((tx + 14, ry + 10), row[0], font=F(16), fill=(20, 18, 12))
            d.text((tx + 194, ry + 10), row[1], font=F(16), fill=(20, 18, 12))
    return img


def scanned_pdf():
    img = doc_image([
        ("가족관계증명서 (스캔본)", 30), ("", 6),
        ("등록기준지: 서울특별시 종로구 세종대로 1", 18),
        ("성명: 박정호   주민등록번호: 850102-1234567", 18),
        ("배우자: 김서연   주민등록번호: 880203-2345678", 18),
        ("자녀: 박하늘   생년월일: 2015년 6월 1일", 18),
        ("연락처: 010-1234-5678", 18),
        ("발급일: 2026년 7월 10일", 18),
    ])
    p = os.path.join(OUT, "_scan_tmp.png"); img.save(p, dpi=(200, 200))
    doc = fitz.open(); page = doc.new_page(width=612, height=792)
    page.insert_image(page.rect, filename=p)
    doc.save(os.path.join(OUT, "2_scanned.pdf")); os.remove(p); print("2_scanned.pdf")


def jpg_photo():
    img = doc_image([
        ("이력서", 34), ("", 6),
        ("이름: 최지우", 22),
        ("전화: 010-8765-4321", 22),
        ("이메일: jiwoo.choi@gmail.com", 22),
        ("주소: 부산광역시 해운대구 센텀로 100", 22),
        ("주민번호: 950707-2345678", 22),
    ], w=820, h=760)
    img.save(os.path.join(OUT, "3_photo.jpg"), quality=88); print("3_photo.jpg")


def table_pdf():
    doc = fitz.open(); page = doc.new_page(width=595, height=842)
    page.insert_font(fontname="F0", fontfile=KFONT)
    page.insert_text((60, 70), "급여명세서 — 2026년 6월", fontname="F0", fontsize=20, color=(0, 0, 0))
    rows = [
        ["성명", "이대호", "사번", "EMP-20301"],
        ["주민번호", "870915-1234567", "부서", "영업1팀"],
        ["계좌", "신한 110-234-567890", "연락처", "010-3456-7890"],
        ["기본급", "3,200,000", "이메일", "daeho@corp.com"],
        ["실수령", "2,880,000", "주소", "인천광역시 남동구 구월로 55"],
    ]
    x0, y0, colw, rh = 60, 110, [90, 180, 70, 175], 40
    for i, row in enumerate(rows):
        y = y0 + i * rh; x = x0
        for j, cell in enumerate(row):
            w = colw[j]
            page.draw_rect(fitz.Rect(x, y, x + w, y + rh), color=(0.3, 0.3, 0.3), width=1)
            page.insert_text((x + 6, y + 25), cell, fontname="F0", fontsize=11, color=(0.1, 0.1, 0.1))
            x += w
    doc.save(os.path.join(OUT, "4_table.pdf")); print("4_table.pdf")


def multipage_pdf():
    doc = fitz.open()
    people = [("김민준", "900315-1234567", "010-2345-6789", "minjun@a.com"),
              ("이서연", "920820-2345678", "010-3456-7890", "seoyeon@b.com"),
              ("박도윤", "880505-1234567", "010-4567-8901", "doyoon@c.com")]
    for i, (nm, rrn, ph, em) in enumerate(people):
        page = doc.new_page(width=595, height=842)
        page.insert_font(fontname="F0", fontfile=KFONT)
        page.insert_text((60, 70), f"계약 당사자 정보 — {i+1}페이지", fontname="F0", fontsize=18, color=(0, 0, 0))
        y = 120
        for label, val in [("성명", nm), ("주민등록번호", rrn), ("연락처", ph), ("이메일", em),
                           ("주소", "서울특별시 마포구 월드컵북로 400")]:
            page.insert_text((60, y), f"{label}: {val}", fontname="F0", fontsize=13, color=(0.1, 0.1, 0.1))
            y += 34
    doc.save(os.path.join(OUT, "5_multipage.pdf")); print("5_multipage.pdf")


# ─────────────── Indian resume, single light column ───────────────
def resume_light():
    doc = fitz.open(); page = doc.new_page(width=595, height=842)
    ink = (0.09, 0.08, 0.06); grey = (0.3, 0.3, 0.3)
    # photo placeholder box (top-right)
    page.draw_rect(fitz.Rect(455, 40, 545, 150), color=(0.5, 0.5, 0.5), width=1)
    page.insert_text((478, 100), "PHOTO", fontsize=10, color=(0.5, 0.5, 0.5))
    # large name at top + title + contact
    page.insert_text((50, 84), "Aarav Sharma", fontname="Times-Bold", fontsize=30, color=ink)
    page.insert_text((50, 110), "Software Engineer", fontsize=13, color=grey)
    page.insert_text((50, 134), "+91 9599320477  |  aarav.sharma@gmail.com", fontsize=12, color=ink)
    # education with institution + place (false-positive bait)
    page.insert_text((50, 190), "EDUCATION", fontname="Times-Bold", fontsize=14, color=ink)
    page.insert_text((50, 214), "Delhi University, Saket", fontsize=11, color=ink)
    page.insert_text((50, 232), "B.Tech Computer Science, 2015-2019", fontsize=10, color=grey)
    page.insert_text((50, 258), "Maharaja Agrasen College", fontsize=11, color=ink)
    page.insert_text((50, 276), "Diploma, Imphal, 2013-2015", fontsize=10, color=grey)
    # personal: wrapping address (two runs) + alt phone + dob
    page.insert_text((320, 190), "PERSONAL", fontname="Times-Bold", fontsize=14, color=ink)
    page.insert_text((320, 214), "Address: Signature Global Mall, Sector 84,", fontsize=10, color=ink)
    page.insert_text((320, 230), "Gurgaon, Haryana 122004", fontsize=10, color=ink)
    page.insert_text((320, 256), "Alt phone: 011-2345-6789", fontsize=10, color=ink)
    page.insert_text((320, 276), "DOB: 1994-07-07", fontsize=10, color=ink)
    doc.save(os.path.join(OUT, "6_resume_light.pdf")); print("6_resume_light.pdf")


# ─────────────── Indian resume, 2-column light/dark (all traps) ───────────────
def resume_dark():
    """Left = white column; Right = dark-green column (white text).
    Reproduces: 48pt serif name, intl phone, wrapping address, standalone
    country, parenthesised proper noun, multiple schools, body-prose org."""
    doc = fitz.open(); page = doc.new_page(width=595, height=842)
    DARK = (0.05, 0.20, 0.12); WHITE = (0.98, 0.98, 0.95); INK = (0.1, 0.1, 0.1); GREY = (0.35, 0.35, 0.35)
    # right dark-green sidebar
    page.draw_rect(fitz.Rect(360, 0, 595, 842), color=None, fill=DARK)

    # ── LEFT white column ──
    # big serif name at very top (48pt → large-text masking path)
    page.insert_text((40, 92), "Aarav Sharma", fontname="Times-Bold", fontsize=44, color=INK)
    page.insert_text((40, 118), "Software Engineer", fontname="Times-Roman", fontsize=13, color=GREY)

    page.insert_text((40, 175), "EDUCATION", fontname="Times-Bold", fontsize=14, color=INK)
    page.insert_text((40, 199), "Delhi University, Saket", fontname="Times-Roman", fontsize=11, color=INK)
    page.insert_text((40, 216), "B.Tech CSE, 2015-2019", fontname="Times-Roman", fontsize=9, color=GREY)
    page.insert_text((40, 240), "Maharaja Agrasen College", fontname="Times-Roman", fontsize=11, color=INK)
    page.insert_text((40, 257), "Diploma, Imphal, 2013-2015", fontname="Times-Roman", fontsize=9, color=GREY)
    page.insert_text((40, 281), "Vidya Niketan School", fontname="Times-Roman", fontsize=11, color=INK)
    page.insert_text((40, 298), "Higher Secondary, 2011-2013", fontname="Times-Roman", fontsize=9, color=GREY)

    page.insert_text((40, 345), "EXPERIENCE", fontname="Times-Bold", fontsize=14, color=INK)
    # body prose containing an org with a country token in the middle (must NOT mask "India")
    page.insert_text((40, 369), "Volunteered with Concern India Foundation on", fontname="Times-Roman", fontsize=10, color=INK)
    page.insert_text((40, 385), "rural education programs across several states and", fontname="Times-Roman", fontsize=10, color=INK)
    page.insert_text((40, 401), "delivered training in multiple districts.", fontname="Times-Roman", fontsize=10, color=INK)

    # a real person name in body prose (positive control: AI labelling this
    # 'name' SHOULD mask it — the org guard must not swallow genuine names)
    page.insert_text((40, 428), "Reference: Rohan Mehta", fontname="Times-Roman", fontsize=10, color=INK)

    page.insert_text((40, 460), "LANGUAGES", fontname="Times-Bold", fontsize=14, color=INK)
    # standalone country line (must NOT be masked / must NOT be a candidate)
    page.insert_text((40, 484), "Korea", fontname="Times-Roman", fontsize=11, color=INK)
    page.insert_text((40, 501), "Hindi, English", fontname="Times-Roman", fontsize=11, color=INK)

    # certification line reproducing the real "Given Exam - TOPIK" trap: an exam
    # name is NOT personal info. Deterministic regex never fires on it; only the
    # AI deep-scan can mislabel it (usually as an unknown type → 'other'). The
    # AI_INJECT golden feeds {type:'other'|<unknown>, value:'TOPIK'} and asserts
    # it stays visible (other defaults to 'ok' after the false-positive fix).
    page.insert_text((40, 520), "Certification: Given Exam - TOPIK", fontname="Times-Roman", fontsize=10, color=GREY)

    # photo placeholder (left, bottom)
    page.draw_rect(fitz.Rect(40, 545, 150, 665), color=(0.6, 0.6, 0.6), width=1)
    page.insert_text((78, 609), "PHOTO", fontname="Times-Roman", fontsize=10, color=GREY)

    # ── RIGHT dark-green column (white text) ──
    page.insert_text((380, 80), "CONTACT", fontname="Times-Bold", fontsize=12, color=WHITE)
    page.insert_text((380, 104), "+91 9599320477", fontname="Times-Roman", fontsize=10, color=WHITE)
    page.insert_text((380, 122), "aarav.sharma@gmail.com", fontname="Times-Roman", fontsize=9, color=WHITE)
    # wrapping address (two runs): line 1 carries an address keyword ("Tower") so
    # it qualifies as an address candidate; line 2 is a lone country (must drop).
    page.insert_text((380, 140), "Signature Global Tower,", fontname="Times-Roman", fontsize=9, color=WHITE)
    page.insert_text((380, 156), "Gurgaon, India", fontname="Times-Roman", fontsize=9, color=WHITE)

    page.insert_text((380, 200), "AWARDS", fontname="Times-Bold", fontsize=12, color=WHITE)
    # parenthesised proper noun that contains 'Korea' as a fragment (must NOT mask)
    page.insert_text((380, 224), "Winner (Koreaz Contest)", fontname="Times-Roman", fontsize=9, color=WHITE)
    # institution with country token (org → not address; 'Korea' fragment guarded)
    page.insert_text((380, 242), "King Sejong Institute, Korea", fontname="Times-Roman", fontsize=9, color=WHITE)

    doc.save(os.path.join(OUT, "7_resume_dark.pdf")); print("7_resume_dark.pdf")


# ─────── 2-column résumé, 3-token name + merged country line (regression) ───────
def resume_2col():
    """Reproduces two real-résumé detection defects with fully synthetic data:
      (1) A 3-token name in a 2-column layout whose surname renders with a
          slightly smaller item height than the given names (exactly what OCR
          word-boxes and mixed typesetting produce). The old name-line assembly
          gated tokens on the PAGE max height, so the shorter last token
          ("Malhotra") was dropped and the surname leaked.  MUST mask all three.
      (2) A country name inside a MULTI-LINE flowing sentence, wrapped so the
          tail visual line reads "Republic of Korea (Koreaz Contest)". This is
          the real-résumé shape: the official name "Ministry of Foreign Affairs
          of the Republic of Korea (Koreaz Contest)" wraps in a narrow column,
          and the wrapped tail becomes its own line segment. "Republic of Korea"
          is 3 country-anchor words, so the old cap (<=2) let it slip past the
          country test and it was proposed as an address candidate. The isolated
          "Korea (Koreaz Contest)" line (dropped by the country anchor even with
          the old cap) is kept too, so both the easy and the realistic case are
          covered. MUST NOT be a candidate.
    """
    doc = fitz.open(); page = doc.new_page(width=595, height=842)
    DARK = (0.05, 0.20, 0.12); WHITE = (0.98, 0.98, 0.95); INK = (0.1, 0.1, 0.1); GREY = (0.35, 0.35, 0.35)
    page.draw_rect(fitz.Rect(360, 0, 595, 842), color=None, fill=DARK)  # right dark sidebar

    # ── LEFT column: 3-token name, surname rendered a touch smaller (item-height
    #    variance like OCR) — the trailing token must still be masked. ──
    page.insert_text((40, 92),  "Ishan",    fontname="Times-Bold", fontsize=26, color=INK)
    page.insert_text((116, 92), "Rohit",    fontname="Times-Bold", fontsize=26, color=INK)
    page.insert_text((188, 92), "Malhotra", fontname="Times-Bold", fontsize=21, color=INK)
    page.insert_text((40, 118), "Software Engineer", fontname="Times-Roman", fontsize=13, color=GREY)

    page.insert_text((40, 175), "EDUCATION", fontname="Times-Bold", fontsize=14, color=INK)
    page.insert_text((40, 199), "Delhi University, Saket", fontname="Times-Roman", fontsize=11, color=INK)
    page.insert_text((40, 240), "Maharaja Agrasen College", fontname="Times-Roman", fontsize=11, color=INK)

    # EXPERIENCE: a flowing sentence that WRAPS across three visual lines. The
    # official body name overflows the column and the wrap point falls right
    # before "Republic", so the tail line is exactly the country-anchored span
    # that leaked as an address candidate in the real résumé. No digits on the
    # tail line (a number would route it to the confirmed-address path instead).
    page.insert_text((40, 380), "EXPERIENCE", fontname="Times-Bold", fontsize=14, color=INK)
    page.insert_text((40, 404), "Represented student delegates before the Ministry of", fontname="Times-Roman", fontsize=10, color=INK)
    page.insert_text((40, 420), "Foreign Affairs of the", fontname="Times-Roman", fontsize=10, color=INK)
    page.insert_text((40, 436), "Republic of Korea (Koreaz Contest)", fontname="Times-Roman", fontsize=10, color=INK)

    # ── RIGHT dark column ──
    page.insert_text((380, 80),  "CONTACT", fontname="Times-Bold", fontsize=12, color=WHITE)
    page.insert_text((380, 104), "+91 9599320477", fontname="Times-Roman", fontsize=10, color=WHITE)
    page.insert_text((380, 122), "ishan.malhotra@gmail.com", fontname="Times-Roman", fontsize=9, color=WHITE)

    page.insert_text((380, 200), "AWARDS", fontname="Times-Bold", fontsize=12, color=WHITE)
    # country + parenthetical award on ONE isolated line (the easy trap, already
    # handled by the country anchor even before the cap change)
    page.insert_text((380, 224), "Korea (Koreaz Contest)", fontname="Times-Roman", fontsize=9, color=WHITE)

    doc.save(os.path.join(OUT, "8_resume_2col.pdf")); print("8_resume_2col.pdf")


# ─────── résumé whose header name WRAPS onto two lines (regression) ───────
def resume_2line():
    """Reproduces the real-résumé defect where the header name renders across
    TWO visual lines (given names on line 1, surname on line 2, same large
    font). The old name-line assembly only grew HORIZONTALLY within the anchor's
    single row, so it captured "MANSI GAZAL" and left the surname "TIWARI" — a
    whole second line — fully exposed. Only phone + email surfaced as confirmed,
    and the name showed up as a truncated "MANSI GAZAL" candidate. Fully
    synthetic. Detection must now assemble the wrapped name whole so activating
    it covers BOTH lines (surname included). The subtitle "Software Developer" is
    a smaller font and must NOT be merged into the name.
    """
    doc = fitz.open(); page = doc.new_page(width=595, height=842)
    INK = (0.09, 0.08, 0.06); GREY = (0.4, 0.4, 0.4)
    # header name split across two lines, same 26pt bold font
    page.insert_text((50, 90),  "MANSI GAZAL", fontname="Times-Bold", fontsize=26, color=INK)
    page.insert_text((50, 120), "TIWARI",      fontname="Times-Bold", fontsize=26, color=INK)
    # subtitle in a clearly smaller font — must stay out of the name
    page.insert_text((50, 150), "Software Developer", fontname="Times-Roman", fontsize=12, color=GREY)
    page.insert_text((50, 180), "Phone: +91 98765 43210", fontname="Times-Roman", fontsize=11, color=INK)
    page.insert_text((50, 200), "Email: mansi.tiwari@example.com", fontname="Times-Roman", fontsize=11, color=INK)
    page.insert_text((50, 240), "EDUCATION", fontname="Times-Bold", fontsize=13, color=INK)
    page.insert_text((50, 262), "Delhi University, B.Tech CSE 2015-2019", fontname="Times-Roman", fontsize=10, color=INK)
    doc.save(os.path.join(OUT, "9_resume_2line.pdf")); print("9_resume_2line.pdf")


if __name__ == "__main__":
    text_pdf(); scanned_pdf(); jpg_photo(); table_pdf(); multipage_pdf()
    resume_light(); resume_dark(); resume_2col(); resume_2line()
    print("done ->", OUT)
