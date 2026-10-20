# JP-1 알파 — 골든 하네스 전체 통과 로그 (2026-10-21)

실행: `cd test/safe && node run.mjs` → **exit 0**
환경: macOS / node v25.6.1 / playwright chrome channel (헤드리스) / Tesseract.js 5.1.1 (`jpn+eng`)

| | 전 (2026-10-20) | 후 |
|---|---|---|
| 단언 수 | 130 | **389** |
| 실패 | 0 | **0** |
| 한국 픽스처 케이스 | 130 | 120 (부분마스킹 모드와 함께 사라진 PHONE_FORMAT 10건) |
| 출력 안전성 (TEXT_LEAK/OUT_*) | 8 | **39** |
| 일본 픽스처 케이스 | 0 | **215** |
| 일본 유닛 (住所 계층 · 電話/FAX) | 0 | **14** |

> `PHONE_FORMAT` 10건이 줄어든 것은 커버리지 손실이 아니다 — 그 단언이 검증하던
> **부분 마스킹 모드 자체가 제거**됐다. `MUST_MASK`/`MUST_NOT_MASK` 의 의미는
> 그대로이고(활성 마스크 사각형에 의한 기하 피복), 부분이 기본값이던 유형은
> 전부 띠가 기본값이 됐다 — 더 많이 가리지, 덜 가리지 않는다.

---

## 전체 출력

```text
… 1_text.pdf
    [autoCount] 1_text.pdf = 9
… 2_scanned.pdf
    [autoCount] 2_scanned.pdf = 3
… 3_photo.jpg
    [autoCount] 3_photo.jpg = 3
… 4_table.pdf
    [autoCount] 4_table.pdf = 5
… 5_multipage.pdf
    [autoCount] 5_multipage.pdf = 10
… 6_resume_light.pdf
    [autoCount] 6_resume_light.pdf = 4
… 7_resume_dark.pdf
    [autoCount] 7_resume_dark.pdf = 2
… 8_resume_2col.pdf
    [autoCount] 8_resume_2col.pdf = 2
… 9_resume_2line.pdf
    [autoCount] 9_resume_2line.pdf = 2
… jp/shikaku_kakuninsho/kenpo.png
    [jp autoCount] jp/shikaku_kakuninsho/kenpo.png [identity_submit] = 5
… jp/shikaku_kakuninsho/kokuho.png
    [jp autoCount] jp/shikaku_kakuninsho/kokuho.png [identity_submit] = 5
… jp/shikaku_kakuninsho/kouki.png
    [jp autoCount] jp/shikaku_kakuninsho/kouki.png [identity_submit] = 3
… jp/unten_menkyo/front.png
    [jp autoCount] jp/unten_menkyo/front.png [identity_submit] = 0
… jp/unten_menkyo/back.png
    [jp autoCount] jp/unten_menkyo/back.png [identity_submit] = 0
… jp/unten_menkyo/back.png
    [jp autoCount] jp/unten_menkyo/back.png [consult_share] = 0
… jp/mynumber_card/front.png
    [jp autoCount] jp/mynumber_card/front.png [identity_submit] = 0
… jp/mynumber_card/back.png
    [jp autoCount] jp/mynumber_card/back.png [identity_submit] = 1
    [jp autoCount] jp/mynumber_card/back.png [my_number_procedure] = 0
… jp/juminhyo/zenin_mynumber.png
    [jp autoCount] jp/juminhyo/zenin_mynumber.png [identity_submit] = 1
    [jp autoCount] jp/juminhyo/zenin_mynumber.png [my_number_procedure] = 0
… jp/juminhyo/ichibu_plain.png
    [jp autoCount] jp/juminhyo/ichibu_plain.png [identity_submit] = 0
… jp/juminhyo/honseki_on.png
    [jp autoCount] jp/juminhyo/honseki_on.png [identity_submit] = 0
    [jp autoCount] jp/juminhyo/honseki_on.png [my_number_procedure] = 0
… jp/juminhyo/gaikokujin.png
    [jp autoCount] jp/juminhyo/gaikokujin.png [identity_submit] = 0
… jp/shikaku_kakuninsho/kenpo.pdf
    [jp autoCount] jp/shikaku_kakuninsho/kenpo.pdf [identity_submit] = 5
… jp/shikaku_kakuninsho/kenpo.jpg
    [jp autoCount] jp/shikaku_kakuninsho/kenpo.jpg [identity_submit] = 5
… jp/juminhyo/zenin_mynumber.jpg
    [jp autoCount] jp/juminhyo/zenin_mynumber.jpg [identity_submit] = 1
… jp/mynumber_card/back.jpg
    [jp autoCount] jp/mynumber_card/back.jpg [identity_submit] = 1
… jp units
… ai_inject
… ai_cat_state
… candidate_dedup

════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
DOC                 CATEGORY         ITEM                                    EXPECTED          ACTUAL            RESULT
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
1_text.pdf          REGRESSION       auto>=5                                 >=5               9                 ✅ PASS
1_text.pdf          REGRESSION       auto<=12                                <=12              9                 ✅ PASS
1_text.pdf          MUST_MASK        900315-1234567                          masked            masked            ✅ PASS
1_text.pdf          MUST_MASK        010-2345-6789                           masked            masked            ✅ PASS
1_text.pdf          MUST_MASK        minjun.kim@hanmail.net                  masked            masked            ✅ PASS
1_text.pdf          MUST_MASK        010-9876-5432                           masked            masked            ✅ PASS
1_text.pdf          MUST_MASK        123456-04-789012                        masked            masked            ✅ PASS
1_text.pdf          MUST_NOT_MASK    한빛테크                                    clear             clear             ✅ PASS
1_text.pdf          NEVER_CANDIDATE  한빛테크                                    not-cand          not-cand          ✅ PASS
1_text.pdf          TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
1_text.pdf          OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
1_text.pdf          OUT_PDF          output pdf metadata                     none              none              ✅ PASS
1_text.pdf          OUT_PNG          output png metadata                     none              none              ✅ PASS
1_text.pdf          OUT_JPG          output jpg metadata                     none              none              ✅ PASS
1_text.pdf          OUT_JPG          output jpg ICC                          generic <=2048B   456B              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
2_scanned.pdf       REGRESSION       auto>=3                                 >=3               3                 ✅ PASS
2_scanned.pdf       REGRESSION       auto<=8                                 <=8               3                 ✅ PASS
2_scanned.pdf       TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
2_scanned.pdf       OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
2_scanned.pdf       OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
3_photo.jpg         REGRESSION       auto>=3                                 >=3               3                 ✅ PASS
3_photo.jpg         REGRESSION       auto<=8                                 <=8               3                 ✅ PASS
3_photo.jpg         OUT_PNG          output png metadata                     none              none              ✅ PASS
3_photo.jpg         OUT_JPG          output jpg metadata                     none              none              ✅ PASS
3_photo.jpg         OUT_JPG          output jpg ICC                          generic <=2048B   456B              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
4_table.pdf         REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
4_table.pdf         REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
4_table.pdf         MUST_MASK        870915-1234567                          masked            masked            ✅ PASS
4_table.pdf         MUST_MASK        010-3456-7890                           masked            masked            ✅ PASS
4_table.pdf         MUST_MASK        daeho@corp.com                          masked            masked            ✅ PASS
4_table.pdf         MUST_MASK        110-234-567890                          masked            masked            ✅ PASS
4_table.pdf         TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
4_table.pdf         OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
4_table.pdf         OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
5_multipage.pdf     REGRESSION       auto>=9                                 >=9               10                ✅ PASS
5_multipage.pdf     REGRESSION       auto<=13                                <=13              10                ✅ PASS
5_multipage.pdf     MUST_MASK        900315-1234567                          masked            masked            ✅ PASS
5_multipage.pdf     MUST_MASK        920820-2345678                          masked            masked            ✅ PASS
5_multipage.pdf     MUST_MASK        880505-1234567                          masked            masked            ✅ PASS
5_multipage.pdf     MUST_MASK        minjun@a.com                            masked            masked            ✅ PASS
5_multipage.pdf     MUST_MASK        seoyeon@b.com                           masked            masked            ✅ PASS
5_multipage.pdf     MUST_MASK        doyoon@c.com                            masked            masked            ✅ PASS
5_multipage.pdf     TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
5_multipage.pdf     OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
5_multipage.pdf     OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
6_resume_light.pdf  REGRESSION       auto>=3                                 >=3               4                 ✅ PASS
6_resume_light.pdf  REGRESSION       auto<=7                                 <=7               4                 ✅ PASS
6_resume_light.pdf  MUST_MASK        +91 9599320477                          masked            masked            ✅ PASS
6_resume_light.pdf  MUST_MASK        aarav.sharma@gmail.com                  masked            masked            ✅ PASS
6_resume_light.pdf  MUST_NOT_MASK    Delhi University                        clear             clear             ✅ PASS
6_resume_light.pdf  MUST_NOT_MASK    Maharaja Agrasen College                clear             clear             ✅ PASS
6_resume_light.pdf  MUST_NOT_MASK    Saket                                   clear             clear             ✅ PASS
6_resume_light.pdf  MUST_NOT_MASK    Imphal                                  clear             clear             ✅ PASS
6_resume_light.pdf  NEVER_CANDIDATE  Delhi University                        not-cand          not-cand          ✅ PASS
6_resume_light.pdf  NEVER_CANDIDATE  Maharaja Agrasen College                not-cand          not-cand          ✅ PASS
6_resume_light.pdf  SHOULD_CANDIDATE Aarav Sharma                            candidate         candidate         ✅ PASS
6_resume_light.pdf  CANDIDATE_MODE   Aarav Sharma                            ok                ok                ✅ PASS
6_resume_light.pdf  NAME_BAR         Aarav Sharma                            tight&contains    hRatio=1.38 conta…✅ PASS
6_resume_light.pdf  TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
6_resume_light.pdf  OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
6_resume_light.pdf  OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
7_resume_dark.pdf   REGRESSION       auto>=2                                 >=2               2                 ✅ PASS
7_resume_dark.pdf   REGRESSION       auto<=4                                 <=4               2                 ✅ PASS
7_resume_dark.pdf   MUST_MASK        +91 9599320477                          masked            masked            ✅ PASS
7_resume_dark.pdf   MUST_MASK        aarav.sharma@gmail.com                  masked            masked            ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Delhi University                        clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Maharaja Agrasen College                clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Vidya Niketan School                    clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    King Sejong Institute                   clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Concern India Foundation                clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Korea                                   clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Koreaz Contest                          clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Imphal                                  clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    Saket                                   clear             clear             ✅ PASS
7_resume_dark.pdf   MUST_NOT_MASK    India                                   clear             clear             ✅ PASS
7_resume_dark.pdf   NEVER_CANDIDATE  Korea                                   not-cand          not-cand          ✅ PASS
7_resume_dark.pdf   NEVER_CANDIDATE  Maharaja Agrasen College                not-cand          not-cand          ✅ PASS
7_resume_dark.pdf   NEVER_CANDIDATE  Vidya Niketan School                    not-cand          not-cand          ✅ PASS
7_resume_dark.pdf   NEVER_CANDIDATE  King Sejong Institute                   not-cand          not-cand          ✅ PASS
7_resume_dark.pdf   NEVER_CANDIDATE  Concern India Foundation                not-cand          not-cand          ✅ PASS
7_resume_dark.pdf   NEVER_CANDIDATE  Delhi University                        not-cand          not-cand          ✅ PASS
7_resume_dark.pdf   NEVER_CANDIDATE  Imphal                                  not-cand          not-cand          ✅ PASS
7_resume_dark.pdf   SHOULD_CANDIDATE Aarav Sharma                            candidate         candidate         ✅ PASS
7_resume_dark.pdf   SHOULD_CANDIDATE Signature Global                        candidate         candidate         ✅ PASS
7_resume_dark.pdf   CANDIDATE_MODE   Aarav Sharma                            ok                ok                ✅ PASS
7_resume_dark.pdf   CANDIDATE_MODE   Signature Global                        ok                ok                ✅ PASS
7_resume_dark.pdf   NAME_BAR         Aarav Sharma                            tight&contains    hRatio=1.35 conta…✅ PASS
7_resume_dark.pdf   DARK_BG          aarav.sharma@gmail.com                  dark bg detected  rgb(13,51,31) dar…ℹ ok
7_resume_dark.pdf   TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
7_resume_dark.pdf   OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
7_resume_dark.pdf   OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
8_resume_2col.pdf   REGRESSION       auto>=2                                 >=2               2                 ✅ PASS
8_resume_2col.pdf   REGRESSION       auto<=4                                 <=4               2                 ✅ PASS
8_resume_2col.pdf   NAME_WHOLE       Ishan Rohit Malhotra                    detected-whole    detected          ✅ PASS
8_resume_2col.pdf   MUST_MASK        Ishan Rohit Malhotra                    masked            masked            ✅ PASS
8_resume_2col.pdf   MUST_MASK        Malhotra                                masked            masked            ✅ PASS
8_resume_2col.pdf   MUST_MASK        +91 9599320477                          masked            masked            ✅ PASS
8_resume_2col.pdf   MUST_MASK        ishan.malhotra@gmail.com                masked            masked            ✅ PASS
8_resume_2col.pdf   MUST_NOT_MASK    Software Engineer                       clear             clear             ✅ PASS
8_resume_2col.pdf   MUST_NOT_MASK    Delhi University                        clear             clear             ✅ PASS
8_resume_2col.pdf   MUST_NOT_MASK    Maharaja Agrasen College                clear             clear             ✅ PASS
8_resume_2col.pdf   MUST_NOT_MASK    Koreaz Contest                          clear             clear             ✅ PASS
8_resume_2col.pdf   MUST_NOT_MASK    Republic of Korea (Koreaz Contest)      clear             clear             ✅ PASS
8_resume_2col.pdf   NEVER_CANDIDATE  Republic of Korea (Koreaz Contest)      not-cand          not-cand          ✅ PASS
8_resume_2col.pdf   NEVER_CANDIDATE  Korea (Koreaz Contest)                  not-cand          not-cand          ✅ PASS
8_resume_2col.pdf   NEVER_CANDIDATE  Korea                                   not-cand          not-cand          ✅ PASS
8_resume_2col.pdf   NEVER_CANDIDATE  Maharaja Agrasen College                not-cand          not-cand          ✅ PASS
8_resume_2col.pdf   NEVER_CANDIDATE  Delhi University                        not-cand          not-cand          ✅ PASS
8_resume_2col.pdf   TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
8_resume_2col.pdf   OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
8_resume_2col.pdf   OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
9_resume_2line.pdf  REGRESSION       auto>=2                                 >=2               2                 ✅ PASS
9_resume_2line.pdf  REGRESSION       auto<=4                                 <=4               2                 ✅ PASS
9_resume_2line.pdf  NAME_WHOLE       MANSI GAZAL TIWARI                      detected-whole    detected          ✅ PASS
9_resume_2line.pdf  MUST_MASK        MANSI GAZAL TIWARI                      masked            masked            ✅ PASS
9_resume_2line.pdf  MUST_MASK        TIWARI                                  masked            masked            ✅ PASS
9_resume_2line.pdf  MUST_MASK        +91 98765 43210                         masked            masked            ✅ PASS
9_resume_2line.pdf  MUST_MASK        mansi.tiwari@example.com                masked            masked            ✅ PASS
9_resume_2line.pdf  MUST_NOT_MASK    Software Developer                      clear             clear             ✅ PASS
9_resume_2line.pdf  MUST_NOT_MASK    Delhi University                        clear             clear             ✅ PASS
9_resume_2line.pdf  NEVER_CANDIDATE  Software Developer                      not-cand          not-cand          ✅ PASS
9_resume_2line.pdf  NEVER_CANDIDATE  Delhi University                        not-cand          not-cand          ✅ PASS
9_resume_2line.pdf  SHOULD_CANDIDATE MANSI GAZAL TIWARI                      candidate         candidate         ✅ PASS
9_resume_2line.pdf  TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
9_resume_2line.pdf  OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
9_resume_2line.pdf  OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_FIELD         kigo                                    detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         bango                                   detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         edaban                                  detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         hokensha_bango                          detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         qr                                      detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         sex                                     detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_MASK          hokensha_bango                          >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          kigo                                    >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          bango                                   >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          edaban                                  >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             13 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced          candidate+banded  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          jigyosho                                <=10%             5 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked (skipped: hihokensha_bang…>0                11                ✅ PASS
jp/shikaku_kakunins…OUT_PNG          output png metadata                     none              none              ✅ PASS
jp/shikaku_kakunins…OUT_JPG          output jpg metadata                     none              none              ✅ PASS
jp/shikaku_kakunins…OUT_JPG          output jpg ICC                          generic <=2048B   456B              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_MASK          hokensha_bango                          >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          kigo                                    >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          bango                                   >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          edaban                                  >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             13 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced          candidate+banded  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked (skipped: hihokensha_bang…>0                10                ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=2                                 >=2               3                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               3                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_MASK          hokensha_bango                          >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          hihokensha_bango                        >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             14 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced          candidate+banded  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked (skipped: kigo,bango,edab…>0                8                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/unten_menkyo/fro…JP_CLASS         unten_menkyo/front                      classified        unten_menkyo/fron…✅ PASS
jp/unten_menkyo/fro…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/unten_menkyo/fro…JP_FIELD         license_no                              detected          detected          ✅ PASS
jp/unten_menkyo/fro…JP_OPTIONAL      license_no                              offered+clear     offered+clear     ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          name                                    <=10%             3 item(s) min 0%  ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          expiry                                  <=10%             10 item(s) min 0% ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          photo                                   <=10%             5 item(s) min 0%  ✅ PASS
jp/unten_menkyo/fro…JP_COVERAGE      boxes checked (skipped: none)           >0                6                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/unten_menkyo/bac…JP_CLASS         unten_menkyo/back                       classified        unten_menkyo/back…✅ PASS
jp/unten_menkyo/bac…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        biko_change                             banded            banded            ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        organ_donor                             banded            banded            ✅ PASS
jp/unten_menkyo/bac…JP_CLEAR         address_loose                           detected+clear    detected+clear    ✅ PASS
jp/unten_menkyo/bac…JP_CANDIDATE     biko_change                             surfaced          candidate+banded  ✅ PASS
jp/unten_menkyo/bac…JP_CANDIDATE     organ_donor                             surfaced          candidate+banded  ✅ PASS
jp/unten_menkyo/bac…JP_COVERAGE      boxes checked (skipped: none)           >0                2                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/unten_menkyo/bac…JP_CLASS         unten_menkyo/back                       classified        unten_menkyo/back…✅ PASS
jp/unten_menkyo/bac…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/unten_menkyo/bac…JP_FIELD         address_loose                           detected          detected          ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        address_loose                           banded            banded            ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        biko_change                             banded            banded            ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        organ_donor                             banded            banded            ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/fr…JP_CLASS         mynumber_card/front                     classified        mynumber_card/fro…✅ PASS
jp/mynumber_card/fr…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/mynumber_card/fr…JP_BANDED        sex                                     banded            banded            ✅ PASS
jp/mynumber_card/fr…JP_BANDED        organ_donor                             banded            banded            ✅ PASS
jp/mynumber_card/fr…JP_CANDIDATE     sex                                     surfaced          candidate+banded  ✅ PASS
jp/mynumber_card/fr…JP_CANDIDATE     organ_donor                             surfaced          candidate+banded  ✅ PASS
jp/mynumber_card/fr…JP_KEEP          name                                    <=10%             3 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_KEEP          address                                 <=10%             15 item(s) min 0% ✅ PASS
jp/mynumber_card/fr…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_KEEP          photo                                   <=10%             8 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_COVERAGE      boxes checked (skipped: none)           >0                7                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/ba…JP_CLASS         mynumber_card/back                      classified        mynumber_card/bac…✅ PASS
jp/mynumber_card/ba…REGRESSION       auto>=1                                 >=1               1                 ✅ PASS
jp/mynumber_card/ba…REGRESSION       auto<=3                                 <=3               1                 ✅ PASS
jp/mynumber_card/ba…JP_BANDED        back_all                                banded            banded            ✅ PASS
jp/mynumber_card/ba…JP_BANDED        my_number                               banded            banded            ✅ PASS
jp/mynumber_card/ba…JP_MASK          ALL(face)                               >=60%             53 item(s) min 10…✅ PASS
jp/mynumber_card/ba…JP_MASK          my_number                               >=60%             2 item(s) min 100%✅ PASS
jp/mynumber_card/ba…JP_MASK          name                                    >=60%             3 item(s) min 100%✅ PASS
jp/mynumber_card/ba…JP_MASK          birth                                   >=60%             7 item(s) min 100%✅ PASS
jp/mynumber_card/ba…JP_MASK          qr                                      >=60%             5 item(s) min 100%✅ PASS
jp/mynumber_card/ba…JP_COVERAGE      boxes checked (skipped: none)           >0                5                 ✅ PASS
jp/mynumber_card/ba…TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
jp/mynumber_card/ba…OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
jp/mynumber_card/ba…OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/ba…JP_CLASS         mynumber_card/back                      classified        mynumber_card/bac…✅ PASS
jp/mynumber_card/ba…REGRESSION       auto<=1                                 <=1               0                 ✅ PASS
jp/mynumber_card/ba…JP_FIELD         my_number                               detected          detected          ✅ PASS
jp/mynumber_card/ba…JP_KEEP          my_number                               <=10%             2 item(s) min 0%  ✅ PASS
jp/mynumber_card/ba…JP_KEEP          name                                    <=10%             3 item(s) min 0%  ✅ PASS
jp/mynumber_card/ba…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/mynumber_card/ba…JP_COVERAGE      boxes checked (skipped: none)           >0                3                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/zenin_m…JP_CLASS         juminhyo                                classified        juminhyo sc=10    ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto>=1                                 >=1               1                 ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto<=4                                 <=4               1                 ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         my_number                               detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         jumin_code                              detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         honseki                                 detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         hittosha                                detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         setaiin                                 detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        jumin_code                              banded            banded            ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        setaiin                                 banded            banded            ✅ PASS
jp/juminhyo/zenin_m…JP_MASK_OR_CAND  m1_my_number                            banded or candida…banded            ✅ PASS
jp/juminhyo/zenin_m…JP_MASK_OR_CAND  m2_my_number                            banded or candida…banded            ✅ PASS
jp/juminhyo/zenin_m…JP_MASK_OR_CAND  m3_my_number                            banded or candida…banded            ✅ PASS
jp/juminhyo/zenin_m…JP_MASK          jumin_code                              >=60%             1 item(s) min 100%✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m1_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m1_hittosha                             surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_name                                 surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_zokugara                             surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_birth                                surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_sex                                  surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_since                                surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_hittosha                             surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_name                                 surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_zokugara                             surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_birth                                surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_sex                                  surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_since                                surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_hittosha                             surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m1_name                                 <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_COVERAGE      boxes checked (skipped: none)           >0                23                ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/zenin_m…JP_CLASS         juminhyo                                classified        juminhyo sc=10    ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        honseki                                 banded            banded            ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m1_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m1_my_number                            <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m2_my_number                            <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m3_my_number                            <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_COVERAGE      boxes checked (skipped: none)           >0                6                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/ichibu_…JP_CLASS         juminhyo                                classified        juminhyo sc=9     ✅ PASS
jp/juminhyo/ichibu_…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/ichibu_…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/juminhyo/ichibu_…JP_KEEP          m1_name                                 <=10%             2 item(s) min 0%  ✅ PASS
jp/juminhyo/ichibu_…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/ichibu_…JP_COVERAGE      boxes checked (skipped: none)           >0                3                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/honseki…JP_CLASS         juminhyo                                classified        juminhyo sc=12    ✅ PASS
jp/juminhyo/honseki…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/honseki…JP_BANDED        honseki                                 banded            banded            ✅ PASS
jp/juminhyo/honseki…JP_BANDED        hittosha                                banded            banded            ✅ PASS
jp/juminhyo/honseki…JP_CANDIDATE     m1_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/honseki…JP_CANDIDATE     m1_hittosha                             surfaced          candidate+banded  ✅ PASS
jp/juminhyo/honseki…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/juminhyo/honseki…JP_KEEP          m1_name                                 <=10%             3 item(s) min 0%  ✅ PASS
jp/juminhyo/honseki…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/honseki…JP_COVERAGE      boxes checked (skipped: none)           >0                5                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/honseki…JP_CLASS         juminhyo                                classified        juminhyo sc=12    ✅ PASS
jp/juminhyo/honseki…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/honseki…JP_BANDED        honseki                                 banded            banded            ✅ PASS
jp/juminhyo/honseki…JP_CANDIDATE     m1_honseki                              surfaced          candidate+banded  ✅ PASS
jp/juminhyo/honseki…JP_COVERAGE      boxes checked (skipped: none)           >0                1                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/gaikoku…JP_CLASS         juminhyo                                classified        juminhyo sc=7     ✅ PASS
jp/juminhyo/gaikoku…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/gaikoku…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/juminhyo/gaikoku…JP_KEEP          m1_name                                 <=10%             2 item(s) min 0%  ✅ PASS
jp/juminhyo/gaikoku…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/gaikoku…JP_COVERAGE      boxes checked (skipped: none)           >0                3                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_MASK          hokensha_bango                          >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          kigo                                    >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          bango                                   >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          edaban                                  >=60%             1 item(s) min 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             14 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced          candidate+banded  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          jigyosho                                <=10%             5 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked (skipped: hihokensha_bang…>0                11                ✅ PASS
jp/shikaku_kakunins…TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
jp/shikaku_kakunins…OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
jp/shikaku_kakunins…OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          banded            banded            ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      banded            banded            ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/zenin_m…JP_CLASS         juminhyo                                classified        juminhyo sc=9     ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto>=1                                 >=1               1                 ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto<=4                                 <=4               1                 ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         my_number                               detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         jumin_code                              detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        jumin_code                              banded            banded            ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        my_number                               banded            banded            ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/ba…JP_CLASS         mynumber_card/back                      classified        mynumber_card/bac…✅ PASS
jp/mynumber_card/ba…REGRESSION       auto>=1                                 >=1               1                 ✅ PASS
jp/mynumber_card/ba…REGRESSION       auto<=3                                 <=3               1                 ✅ PASS
jp/mynumber_card/ba…JP_BANDED        back_all                                banded            banded            ✅ PASS
jp/mynumber_card/ba…JP_BANDED        my_number                               banded            banded            ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
(jp units)          JP_ADDRESS       都道府県+市区+丁目番地号                           東京都千代田区霞が関1丁目2番3号…東京都千代田区霞が関1丁目2番3号…✅ PASS
(jp units)          JP_ADDRESS       郵便番号を伴う → strong (自動)                   〒100-8926東京都千代田区霞…〒100-8926東京都千代田区霞…✅ PASS
(jp units)          JP_ADDRESS       漢数字の丁目番号も拾う                             京都府京都市中京区三条通一丁目二番…京都府京都市中京区三条通一丁目二番…✅ PASS
(jp units)          JP_ADDRESS       架空の県名はアンカーにならない（保険者名）                   no address        none              ✅ PASS
(jp units)          JP_ADDRESS       発行者名（見本市長）を住所と読まない                      no address        none              ✅ PASS
(jp units)          JP_ADDRESS       株式会社名を住所と読まない                           no address        none              ✅ PASS
(jp units)          JP_ADDRESS       機関名は減点 — 部分一致は閾値割れ                      no address        大阪府見本市 s=1        ✅ PASS
(jp units)          JP_ADDRESS       完全な住所は機関名が続いても候補として残る                   東京都新宿区西新宿2丁目8番1号 …東京都新宿区西新宿2丁目8番1号 …✅ PASS
(jp units)          JP_TEL           市外局番2桁                                  03-1234-5678      03-1234-5678      ✅ PASS
(jp units)          JP_TEL           携帯                                      090-1234-5678     090-1234-5678     ✅ PASS
(jp units)          JP_TEL           フリーダイヤル 0120                            0120-123-456      0120-123-456      ✅ PASS
(jp units)          JP_TEL           フリーダイヤル 0800                            0800-123-4567     0800-123-4567     ✅ PASS
(jp units)          JP_TEL           ハイフンなしは候補どまり                            09012345678 (cand…09012345678 (cand…✅ PASS
(jp units)          JP_TEL           11桁を超える数字列は電話ではない                       no match          none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
7_resume_dark.pdf   AI_INJECT        college labelled as person name [name:M…not_masked        visible(company/o…✅ PASS
7_resume_dark.pdf   AI_INJECT        foundation labelled as person name [nam…not_masked        visible(company/o…✅ PASS
7_resume_dark.pdf   AI_INJECT        institute labelled as name [name:King S…not_masked        visible(company/o…✅ PASS
7_resume_dark.pdf   AI_INJECT        lone country labelled as address [addre…dropped           dropped           ✅ PASS
7_resume_dark.pdf   AI_INJECT        lone country labelled as name [name:Ind…dropped           dropped           ✅ PASS
7_resume_dark.pdf   AI_INJECT        country adjective labelled as name [nam…dropped           dropped           ✅ PASS
7_resume_dark.pdf   AI_INJECT        country+parenthetical labelled as addre…dropped           dropped           ✅ PASS
7_resume_dark.pdf   AI_INJECT        exam name labelled 'other' stays visibl…not_masked        visible(other/ok) ✅ PASS
7_resume_dark.pdf   AI_INJECT        exam name with UNKNOWN type → 'other', …not_masked        visible(other/ok) ✅ PASS
7_resume_dark.pdf   AI_INJECT        contest name labelled 'other' stays vis…not_masked        visible(other/ok) ✅ PASS
7_resume_dark.pdf   AI_INJECT        genuine body name (positive control) [n…masked            masked            ✅ PASS
7_resume_dark.pdf   AI_CAT_STATE     name stays enabled                      on+checked        enabled=true chec…✅ PASS
7_resume_dark.pdf   AI_CAT_STATE     company stays enabled                   on+checked        enabled=true chec…✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
6_resume_light.pdf  CANDIDATE_DEDUP  candidate contained in confirmed name i…removed           removed           ✅ PASS
6_resume_light.pdf  CONFIRMED_SURVIV…confirmed kept [Aarav Sharma Verma]     survives          survives          ✅ PASS
6_resume_light.pdf  CANDIDATE_DEDUP  candidate adding a token beyond confirm…kept              kept              ✅ PASS
6_resume_light.pdf  CONFIRMED_SURVIV…confirmed kept [Aarav]                  survives          survives          ✅ PASS
════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════

Summary by category:
  REGRESSION         46 pass / 0 fail
  MUST_MASK          27 pass / 0 fail
  MUST_NOT_MASK      22 pass / 0 fail
  NEVER_CANDIDATE    17 pass / 0 fail
  TEXT_LEAK          10 pass / 0 fail
  OUT_PDF            20 pass / 0 fail
  OUT_PNG            3 pass / 0 fail
  OUT_JPG            6 pass / 0 fail
  SHOULD_CANDIDATE   4 pass / 0 fail
  CANDIDATE_MODE     3 pass / 0 fail
  NAME_BAR           2 pass / 0 fail
  NAME_WHOLE         2 pass / 0 fail
  JP_CLASS           19 pass / 0 fail
  JP_FIELD           16 pass / 0 fail
  JP_BANDED          41 pass / 0 fail
  JP_MASK            24 pass / 0 fail
  JP_CANDIDATE       30 pass / 0 fail
  JP_KEEP            46 pass / 0 fail
  JP_COVERAGE        15 pass / 0 fail
  JP_OPTIONAL        1 pass / 0 fail
  JP_CLEAR           1 pass / 0 fail
  JP_MASK_OR_CAND    3 pass / 0 fail
  JP_ADDRESS         8 pass / 0 fail
  JP_TEL             6 pass / 0 fail
  AI_INJECT          11 pass / 0 fail
  AI_CAT_STATE       2 pass / 0 fail
  CANDIDATE_DEDUP    2 pass / 0 fail
  CONFIRMED_SURVIVES 2 pass / 0 fail

  TOTAL: 389/389 pass, 0 FAIL

  ⚠ console errors:
    PageError: Failed to update a ServiceWorker for scope ('http://127.0.0.1:49547/safe/') with script ('Unknown'): Not found
```

---

## 하네스가 공허하지 않다는 증거 (변이 프로브 4건)

각 변이를 **실제로 주입하고 재측정**했다. 통과하는 하네스가 *무엇을 잡는지* 모르면
초록색은 아무 말도 하지 않는다.

| # | 주입한 변이 | 결과 |
|---|---|---|
| 1 | `資格確認書` 구조 폴백 비활성화 (OCR이 `保険者番号` 레이블을 뭉갠 경우) | kenpo **3건 실패** (JP_FIELD·JP_BANDED·JP_MASK `hokensha_bango`), kouki **1건 실패** (`hihokensha_bango`) |
| 2 | 세대원 블록(`setaiin`) 규칙 비활성화 | zenin_mynumber **13건 실패** (m2/m3 전 필드 JP_CANDIDATE 미탐) |
| 3 | `keep` 레벨을 `recommend` 로 승격 (남겨야 할 항목을 가림) | kenpo **4건 실패** (JP_KEEP name·birth·address·expiry, 피복 100%) |
| 4 | 박스 0건 검사 시 통과 여부 (`JP_COVERAGE` 가드 자체) | 가드 추가 직후 **실제로 1건 실패** — `mask:["ALL"]` 경로가 카운터를 올리지 않고 있었다. 수정함 |

변이 4는 내가 넣은 가드가 **그 즉시 내 자신의 집계 결함을 잡은 것**이다.
`canonical_sweep.rb` 가 sitemap 이 죽으면 0건 검사하고 통과하던 것과 같은 모양을
그 교훈이 적힌 저장소에서 또 만들 뻔했다.

## 목적 게이트가 실제로 움직이는가 (차등 케이스)

`jp/unten_menkyo/back.png` 하나를 두 목적으로 돌린다 — **같은 문서, 같은 필드, 반대 결과**:

| 목적 | `address_loose` (備考欄의 住所変更 줄) |
|---|---|
| `identity_submit` | `optional` → **JP_CLEAR: detected+clear** (제시만, 띠 없음) |
| `consult_share` | `recommend` → **JP_BANDED: banded** (기본 ON) |

`require_clear` 가 없으면 "相談用共有에서 띠가 켜진다"는 단언은 **모든 목적에서 켜져 있어도**
통과한다. 게이트 테스트는 반대 방향이 함께 있어야 의미가 생긴다.

## 알파 픽스처가 실행할 수 없는 두 규칙 — 유닛으로 고정

알파 4종에는 전화번호가 없고, 住所 는 네 문서 모두 `keep` 이라 주소 계층의 **점수 판정이
아무것도 결정하지 않는다.** 커버리지 없이 내보내는 대신 유닛으로 박았다
(`specs.json` 의 `jp_units`, 14건 전부 통과):

- 都道府県+市区+丁目番地号 / 郵便番号 동반 시 `strong`(자동) / **漢数字** 丁目番地号
- 架空県(保険者名)·見本市長(발행자)·株式会社(사업소명)를 **주소로 읽지 않음**
- 기관명은 **감점(−2)** — 부분 일치는 임계 아래로 떨어지고, 완전한 주소는 후보로 **남는다**
- 전화: 市外局番 2桁 / 携帯 / 0120 / 0800 / 하이픈 없는 값은 **후보까지만** / 12자리는 전화 아님

## 서비스워커 회귀 (변경 없음 확인)

`cd test/sw && node offline_resilience.mjs` → **9/9 통과**
(Phase 1 설치 · Phase 2 `/safe/` 503 주입 중 업데이트에서 구 캐시 생존 · Phase 3 복구)
