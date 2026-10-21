# SafeFile JP-1 S3c — 골든 전체 로그

실행: `cd test/safe && node run.mjs` (실제 Chrome, 2026-10-21)
보고: [`docs/jp/s3c_report.md`](s3c_report.md)

```
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
    [jp autoCount] jp/mynumber_card/back.png [my_number_procedure 未確認] = 1
… jp/juminhyo/zenin_mynumber.png
    [jp autoCount] jp/juminhyo/zenin_mynumber.png [identity_submit] = 0
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
    [jp autoCount] jp/juminhyo/zenin_mynumber.jpg [identity_submit] = 0
… jp/mynumber_card/back.jpg
    [jp autoCount] jp/mynumber_card/back.jpg [identity_submit] = 1
… jp/shikaku_kakuninsho/kenpo.png
    [jp autoCount] jp/shikaku_kakuninsho/kenpo.png [my_number_procedure] = 0
… legal matrix
… jp multipage
… jp units
… jp my_number
… jp merged rows
… jp unlabelled block
… jp classification warning
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
jp/shikaku_kakunins…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_FIELD         kigo                                    detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         bango                                   detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         edaban                                  detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         hokensha_bango                          detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         qr                                      detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_FIELD         sex                                     detected          detected          ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr                                      survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr (categories restored)                restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango                          survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango (categories restored)    restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_AUTO_SET      auto fields == expected set             bango,edaban,hoke…bango,edaban,hoke…✅ PASS
jp/shikaku_kakunins…JP_INK           hokensha_bango                          all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           kigo                                    all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           bango                                   all glyphs covered3 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           edaban                                  all glyphs covered2 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             13 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced(+covered…candidate+covered ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          jigyosho                                <=10%             5 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked                           >=1               11                ✅ PASS
jp/shikaku_kakunins…OUT_PNG          output png metadata                     none              none              ✅ PASS
jp/shikaku_kakunins…OUT_JPG          output jpg metadata                     none              none              ✅ PASS
jp/shikaku_kakunins…OUT_JPG          output jpg ICC                          generic <=2048B   456B              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr                                      survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr (categories restored)                restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango                          survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango (categories restored)    restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_AUTO_SET      auto fields == expected set             bango,edaban,hoke…bango,edaban,hoke…✅ PASS
jp/shikaku_kakunins…JP_INK           hokensha_bango                          all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           kigo                                    all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           bango                                   all glyphs covered3 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           edaban                                  all glyphs covered2 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             13 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced(+covered…candidate+covered ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked                           >=1               10                ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=2                                 >=2               3                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               3                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          located+on+in-mas…banded ×2         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr                                      survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr (categories restored)                restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango                          survives all-cate…banded ×2         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango (categories restored)    restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_AUTO_SET      auto fields == expected set             hokensha_bango,qr hokensha_bango,qr ✅ PASS
jp/shikaku_kakunins…JP_INK           hokensha_bango                          all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           hihokensha_bango                        all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             14 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced(+covered…candidate+covered ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked                           >=1               8                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/unten_menkyo/fro…JP_CLASS         unten_menkyo/front                      classified        unten_menkyo/fron…✅ PASS
jp/unten_menkyo/fro…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/unten_menkyo/fro…JP_FIELD         license_no                              detected          detected          ✅ PASS
jp/unten_menkyo/fro…JP_CLEAR         license_no                              detected+clear    detected+clear ×1 ✅ PASS
jp/unten_menkyo/fro…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          name                                    <=10%             3 item(s) min 0%  ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          expiry                                  <=10%             10 item(s) min 0% ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          photo                                   <=10%             5 item(s) min 0%  ✅ PASS
jp/unten_menkyo/fro…JP_KEEP          license_no                              <=10%             3 item(s) min 0%  ✅ PASS
jp/unten_menkyo/fro…JP_COVERAGE      boxes checked                           >=1               6                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/unten_menkyo/bac…JP_CLASS         unten_menkyo/back                       classified        unten_menkyo/back…✅ PASS
jp/unten_menkyo/bac…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        biko_change                             located+on+in-mas…banded ×1         ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        organ_donor                             located+on+in-mas…banded ×1         ✅ PASS
jp/unten_menkyo/bac…JP_CLEAR         address_loose                           detected+clear    detected+clear ×1 ✅ PASS
jp/unten_menkyo/bac…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/unten_menkyo/bac…JP_CANDIDATE     biko_change                             surfaced(+covered…candidate+covered ✅ PASS
jp/unten_menkyo/bac…JP_CANDIDATE     organ_donor                             surfaced(+covered…candidate+covered ✅ PASS
jp/unten_menkyo/bac…JP_COVERAGE      boxes checked                           >=1               2                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/unten_menkyo/bac…JP_CLASS         unten_menkyo/back                       classified        unten_menkyo/back…✅ PASS
jp/unten_menkyo/bac…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/unten_menkyo/bac…JP_FIELD         address_loose                           detected          detected          ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        address_loose                           located+on+in-mas…banded ×1         ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        biko_change                             located+on+in-mas…banded ×1         ✅ PASS
jp/unten_menkyo/bac…JP_BANDED        organ_donor                             located+on+in-mas…banded ×1         ✅ PASS
jp/unten_menkyo/bac…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/fr…JP_CLASS         mynumber_card/front                     classified        mynumber_card/fro…✅ PASS
jp/mynumber_card/fr…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/mynumber_card/fr…JP_BANDED        sex                                     located+on+in-mas…banded ×1         ✅ PASS
jp/mynumber_card/fr…JP_BANDED        organ_donor                             located+on+in-mas…banded ×1         ✅ PASS
jp/mynumber_card/fr…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/mynumber_card/fr…JP_CANDIDATE     sex                                     surfaced(+covered…candidate+covered ✅ PASS
jp/mynumber_card/fr…JP_CANDIDATE     organ_donor                             surfaced(+covered…candidate+covered ✅ PASS
jp/mynumber_card/fr…JP_KEEP          name                                    <=10%             3 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_KEEP          address                                 <=10%             15 item(s) min 0% ✅ PASS
jp/mynumber_card/fr…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_KEEP          photo                                   <=10%             8 item(s) min 0%  ✅ PASS
jp/mynumber_card/fr…JP_COVERAGE      boxes checked                           >=1               7                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/ba…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/mynumber_card/ba…JP_CLASS         mynumber_card/back                      classified        mynumber_card/bac…✅ PASS
jp/mynumber_card/ba…REGRESSION       auto>=1                                 >=1               1                 ✅ PASS
jp/mynumber_card/ba…REGRESSION       auto<=3                                 <=3               1                 ✅ PASS
jp/mynumber_card/ba…JP_BANDED        back_all                                located+on+in-mas…banded ×1         ✅ PASS
jp/mynumber_card/ba…JP_BANDED        my_number                               located+on+in-mas…banded ×1         ✅ PASS
jp/mynumber_card/ba…JP_LEGAL         back_all                                survives all-cate…banded ×1         ✅ PASS
jp/mynumber_card/ba…JP_LEGAL         back_all (categories restored)          restored+none-off restored          ✅ PASS
jp/mynumber_card/ba…JP_AUTO_SET      auto fields == expected set             back_all          back_all          ✅ PASS
jp/mynumber_card/ba…JP_MASK          ALL(face)                               >=60%             53 item(s) min 10…✅ PASS
jp/mynumber_card/ba…JP_INK           my_number                               all glyphs covered12 comp, worst 10…✅ PASS
jp/mynumber_card/ba…JP_MASK          name                                    >=60%             3 item(s) min 100%✅ PASS
jp/mynumber_card/ba…JP_MASK          birth                                   >=60%             7 item(s) min 100%✅ PASS
jp/mynumber_card/ba…JP_MASK          qr                                      >=60%             5 item(s) min 100%✅ PASS
jp/mynumber_card/ba…JP_COVERAGE      boxes checked                           >=1               5                 ✅ PASS
jp/mynumber_card/ba…TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
jp/mynumber_card/ba…OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
jp/mynumber_card/ba…OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/ba…JP_MN_BOX        confirmation checkbox                   shown             shown             ✅ PASS
jp/mynumber_card/ba…JP_CLASS         mynumber_card/back                      classified        mynumber_card/bac…✅ PASS
jp/mynumber_card/ba…REGRESSION       auto<=1                                 <=1               0                 ✅ PASS
jp/mynumber_card/ba…JP_FIELD         my_number                               detected          detected          ✅ PASS
jp/mynumber_card/ba…JP_CLEAR         my_number                               detected+clear    detected+clear ×1 ✅ PASS
jp/mynumber_card/ba…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/mynumber_card/ba…JP_KEEP          my_number                               <=10%             2 item(s) min 0%  ✅ PASS
jp/mynumber_card/ba…JP_KEEP          name                                    <=10%             3 item(s) min 0%  ✅ PASS
jp/mynumber_card/ba…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/mynumber_card/ba…JP_COVERAGE      boxes checked                           >=1               3                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/ba…JP_MN_BOX        confirmation checkbox                   shown             shown             ✅ PASS
jp/mynumber_card/ba…JP_CLASS         mynumber_card/back                      classified        mynumber_card/bac…✅ PASS
jp/mynumber_card/ba…JP_BANDED        back_all                                located+on+in-mas…banded ×1         ✅ PASS
jp/mynumber_card/ba…JP_BANDED        my_number                               located+on+in-mas…banded ×1         ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/zenin_m…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/juminhyo/zenin_m…JP_CLASS         juminhyo                                classified        juminhyo sc=10    ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto<=4                                 <=4               0                 ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         my_number                               detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         jumin_code                              detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         honseki                                 detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         hittosha                                detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         setaiin                                 detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        jumin_code                              located+on+in-mas…banded ×1         ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        setaiin                                 located+on+in-mas…banded ×13        ✅ PASS
jp/juminhyo/zenin_m…JP_LEGAL         my_number                               survives all-cate…banded ×3         ✅ PASS
jp/juminhyo/zenin_m…JP_LEGAL         my_number (categories restored)         restored+none-off restored          ✅ PASS
jp/juminhyo/zenin_m…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/juminhyo/zenin_m…JP_MASK_OR_CAND  m1_my_number                            banded(+covered) …banded 12 comp, w…✅ PASS
jp/juminhyo/zenin_m…JP_MASK_OR_CAND  m2_my_number                            banded(+covered) …banded 12 comp, w…✅ PASS
jp/juminhyo/zenin_m…JP_MASK_OR_CAND  m3_my_number                            banded(+covered) …banded 11 comp, w…✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     jumin_code                              surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m1_honseki                              surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m1_hittosha                             surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_name                                 surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_zokugara                             surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_birth                                surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_sex                                  surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_since                                surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_honseki                              surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m2_hittosha                             surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_name                                 surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_zokugara                             surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_birth                                surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_sex                                  surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_since                                surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_honseki                              surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_CANDIDATE     m3_hittosha                             surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m1_name                                 <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_COVERAGE      boxes checked                           >=1               23                ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/zenin_m…JP_MN_BOX        confirmation checkbox                   shown             shown             ✅ PASS
jp/juminhyo/zenin_m…JP_CLASS         juminhyo                                classified        juminhyo sc=10    ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/zenin_m…JP_CLEAR         honseki                                 detected+clear    detected+clear ×3 ✅ PASS
jp/juminhyo/zenin_m…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/juminhyo/zenin_m…JP_OPTIONAL      m1_honseki                              offered+clear     offered+clear     ✅ PASS
jp/juminhyo/zenin_m…JP_OPTIONAL      m2_honseki                              offered+clear     offered+clear     ✅ PASS
jp/juminhyo/zenin_m…JP_OPTIONAL      m3_honseki                              offered+clear     offered+clear     ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m1_my_number                            <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m2_my_number                            <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_KEEP          m3_my_number                            <=10%             1 item(s) min 0%  ✅ PASS
jp/juminhyo/zenin_m…JP_COVERAGE      boxes checked                           >=1               6                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/ichibu_…JP_CLASS         juminhyo                                classified        juminhyo sc=9     ✅ PASS
jp/juminhyo/ichibu_…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/ichibu_…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/juminhyo/ichibu_…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/juminhyo/ichibu_…JP_KEEP          m1_name                                 <=10%             2 item(s) min 0%  ✅ PASS
jp/juminhyo/ichibu_…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/ichibu_…JP_COVERAGE      boxes checked                           >=1               3                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/honseki…JP_CLASS         juminhyo                                classified        juminhyo sc=12    ✅ PASS
jp/juminhyo/honseki…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/honseki…JP_BANDED        honseki                                 located+on+in-mas…banded ×1         ✅ PASS
jp/juminhyo/honseki…JP_BANDED        hittosha                                located+on+in-mas…banded ×1         ✅ PASS
jp/juminhyo/honseki…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/juminhyo/honseki…JP_CANDIDATE     m1_honseki                              surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/honseki…JP_CANDIDATE     m1_hittosha                             surfaced(+covered…candidate+covered ✅ PASS
jp/juminhyo/honseki…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/juminhyo/honseki…JP_KEEP          m1_name                                 <=10%             3 item(s) min 0%  ✅ PASS
jp/juminhyo/honseki…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/honseki…JP_COVERAGE      boxes checked                           >=1               5                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/honseki…JP_CLASS         juminhyo                                classified        juminhyo sc=12    ✅ PASS
jp/juminhyo/honseki…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/honseki…JP_CLEAR         honseki                                 detected+clear    detected+clear ×1 ✅ PASS
jp/juminhyo/honseki…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/juminhyo/honseki…JP_OPTIONAL      m1_honseki                              offered+clear     offered+clear     ✅ PASS
jp/juminhyo/honseki…JP_COVERAGE      boxes checked                           >=1               1                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/gaikoku…JP_CLASS         juminhyo                                classified        juminhyo sc=7     ✅ PASS
jp/juminhyo/gaikoku…REGRESSION       auto<=2                                 <=2               0                 ✅ PASS
jp/juminhyo/gaikoku…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/juminhyo/gaikoku…JP_KEEP          address                                 <=10%             13 item(s) min 0% ✅ PASS
jp/juminhyo/gaikoku…JP_KEEP          m1_name                                 <=10%             2 item(s) min 0%  ✅ PASS
jp/juminhyo/gaikoku…JP_KEEP          m1_birth                                <=10%             7 item(s) min 0%  ✅ PASS
jp/juminhyo/gaikoku…JP_COVERAGE      boxes checked                           >=1               3                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr                                      survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr (categories restored)                restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango                          survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango (categories restored)    restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_AUTO_SET      auto fields == expected set             bango,edaban,hoke…bango,edaban,hoke…✅ PASS
jp/shikaku_kakunins…JP_INK           hokensha_bango                          all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           kigo                                    all glyphs covered8 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           bango                                   all glyphs covered3 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_INK           edaban                                  all glyphs covered2 comp, worst 100%✅ PASS
jp/shikaku_kakunins…JP_MASK          qr                                      >=60%             14 item(s) min 10…✅ PASS
jp/shikaku_kakunins…JP_CANDIDATE     sex                                     surfaced(+covered…candidate+covered ✅ PASS
jp/shikaku_kakunins…JP_KEEP          name                                    <=10%             2 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          birth                                   <=10%             7 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          address                                 <=10%             14 item(s) min 0% ✅ PASS
jp/shikaku_kakunins…JP_KEEP          expiry                                  <=10%             8 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_KEEP          jigyosho                                <=10%             5 item(s) min 0%  ✅ PASS
jp/shikaku_kakunins…JP_COVERAGE      boxes checked                           >=1               11                ✅ PASS
jp/shikaku_kakunins…TEXT_LEAK        output pdf                              0 chars           0 chars           ✅ PASS
jp/shikaku_kakunins…OUT_PDF          output pdf revisions                    1 %%EOF           1 %%EOF           ✅ PASS
jp/shikaku_kakunins…OUT_PDF          output pdf metadata                     none              none              ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto>=4                                 >=4               5                 ✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=8                                 <=8               5                 ✅ PASS
jp/shikaku_kakunins…JP_BANDED        kigo                                    located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        bango                                   located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        edaban                                  located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        hokensha_bango                          located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_BANDED        qr                                      located+on+in-mas…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr                                      survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         qr (categories restored)                restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango                          survives all-cate…banded ×1         ✅ PASS
jp/shikaku_kakunins…JP_LEGAL         hokensha_bango (categories restored)    restored+none-off restored          ✅ PASS
jp/shikaku_kakunins…JP_AUTO_SET      auto fields ⊆ allowlist                 ⊆ kigo,bango,edab…bango,edaban,hoke…✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/juminhyo/zenin_m…JP_CLASS         juminhyo                                classified        juminhyo sc=9     ✅ PASS
jp/juminhyo/zenin_m…REGRESSION       auto<=4                                 <=4               0                 ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         my_number                               detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_FIELD         jumin_code                              detected          detected          ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        jumin_code                              located+on+in-mas…banded ×1         ✅ PASS
jp/juminhyo/zenin_m…JP_BANDED        my_number                               located+on+in-mas…banded ×3         ✅ PASS
jp/juminhyo/zenin_m…JP_AUTO_SET      auto fields ⊆ allowlist                 ⊆ (none)          (none)            ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/mynumber_card/ba…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/mynumber_card/ba…JP_CLASS         mynumber_card/back                      classified        mynumber_card/bac…✅ PASS
jp/mynumber_card/ba…REGRESSION       auto>=1                                 >=1               1                 ✅ PASS
jp/mynumber_card/ba…REGRESSION       auto<=3                                 <=3               1                 ✅ PASS
jp/mynumber_card/ba…JP_BANDED        back_all                                located+on+in-mas…banded ×1         ✅ PASS
jp/mynumber_card/ba…JP_BANDED        my_number                               located+on+in-mas…banded ×1         ✅ PASS
jp/mynumber_card/ba…JP_LEGAL         back_all                                survives all-cate…banded ×1         ✅ PASS
jp/mynumber_card/ba…JP_LEGAL         back_all (categories restored)          restored+none-off restored          ✅ PASS
jp/mynumber_card/ba…JP_AUTO_SET      auto fields ⊆ allowlist                 ⊆ back_all        back_all          ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/shikaku_kakunins…JP_WARN          blocking banner                         absent            absent            ✅ PASS
jp/shikaku_kakunins…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
jp/shikaku_kakunins…REGRESSION       auto<=0                                 <=0               0                 ✅ PASS
jp/shikaku_kakunins…JP_AUTO_SET      auto fields == expected set             (none)            (none)            ✅ PASS
jp/shikaku_kakunins…JP_EMPTY         no-rules-for-purpose notice             shown             shown             ✅ PASS
jp/shikaku_kakunins…JP_ENTITIES      jp entities                             0                 0                 ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
(legal matrix)      JP_MATRIX        JP_RULES == jp_legal_matrix_alpha4.json identical         188 (doc, field, …✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/2page 表→裏        JP_PAGECLASS     per-page doc/side                       mynumber_card/fro…mynumber_card/fro…✅ PASS
jp/2page 表→裏        JP_BACK_ONLY     back_all pages                          [1]               [1]               ✅ PASS
jp/2page 表→裏        JP_BACK_COVER    page 1 covered                          >=99%             100%              ✅ PASS
jp/2page 表→裏        JP_FRONT_CLEAR   page 0 not full-face                    <=60%             8%                ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/2page 裏→表        JP_PAGECLASS     per-page doc/side                       mynumber_card/bac…mynumber_card/bac…✅ PASS
jp/2page 裏→表        JP_BACK_ONLY     back_all pages                          [0]               [0]               ✅ PASS
jp/2page 裏→表        JP_BACK_COVER    page 0 covered                          >=99%             100%              ✅ PASS
jp/2page 裏→表        JP_FRONT_CLEAR   page 1 not full-face                    <=60%             8%                ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/2page 表 + 裏(タイトル…JP_PAGECLASS     per-page doc/side                       mynumber_card/fro…mynumber_card/fro…✅ PASS
jp/2page 表 + 裏(タイトル…JP_BACKANCHOR    page 2 promoted via back anchor         true              true              ✅ PASS
jp/2page 表 + 裏(タイトル…JP_ENTITIES      page 1 jp entities                      >=1               2                 ✅ PASS
jp/2page 表 + 裏(タイトル…JP_ENTITIES      page 2 jp entities                      >=1               2                 ✅ PASS
jp/2page 表 + 裏(タイトル…JP_BACK_ONLY     back_all pages                          [1]               [1]               ✅ PASS
jp/2page 表 + 裏(タイトル…JP_BACK_COVER    page 2 coverage                         >=99%             100%              ✅ PASS
jp/2page 表 + 裏(タイトル…JP_FRONT_CLEAR   page 1 not full-face                    <=60%             8%                ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
jp/2page 表 + 無関係な添付…JP_PAGECLASS     per-page doc/side                       mynumber_card/fro…mynumber_card/fro…✅ PASS
jp/2page 表 + 無関係な添付…JP_BACKANCHOR    page 2 promoted via back anchor         false             false             ✅ PASS
jp/2page 表 + 無関係な添付…JP_ENTITIES      page 1 jp entities                      >=1               2                 ✅ PASS
jp/2page 表 + 無関係な添付…JP_ENTITIES      page 2 jp entities                      0                 0                 ✅ PASS
jp/2page 表 + 無関係な添付…JP_BACK_ONLY     back_all pages                          []                []                ✅ PASS
jp/2page 表 + 無関係な添付…JP_ATTACH_CLEAR  page 2 coverage                         <=10%             0%                ✅ PASS
jp/2page 表 + 無関係な添付…JP_FRONT_CLEAR   page 1 not full-face                    <=60%             8%                ✅ PASS
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
(jp units)          JP_MYNUM_CD      valid 123456789018                      true              true              ✅ PASS
(jp units)          JP_MYNUM_CD      valid (sum mod 11 == 0 → check 0) 30166…true              true              ✅ PASS
(jp units)          JP_MYNUM_CD      valid (sum mod 11 == 1 → check 0) 91390…true              true              ✅ PASS
(jp units)          JP_MYNUM_CD      valid (all nines body) 999999999996     true              true              ✅ PASS
(jp units)          JP_MYNUM_CD      invalid: check digit +1 123456789019    false             false             ✅ PASS
(jp units)          JP_MYNUM_CD      invalid: 11 digits 12345678901          false             false             ✅ PASS
(jp units)          JP_MYNUM_CD      invalid: 13 digits 1234567890180        false             false             ✅ PASS
(jp units)          JP_MYNUM_CD      invalid: non-digit 12345678901X         false             false             ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
(jp synth)          JP_CLASS         valid 個人番号 · 本人確認提出 → gate, banded      juminhyo          juminhyo          ✅ PASS
(jp synth)          JP_MYNUM_LEVEL   valid 個人番号 · 本人確認提出 → gate, banded      gate              gate              ✅ PASS
(jp synth)          JP_MYNUM_NOTE    valid 個人番号 · 本人確認提出 → gate, banded note (none)            (none)            ✅ PASS
(jp synth)          JP_MYNUM_BAND    valid 個人番号 · 本人確認提出 → gate, banded band banded            banded            ✅ PASS
(jp synth)          JP_MYNUM_GEOM    valid 個人番号 · 本人確認提出 → gate, banded valu…masked            masked            ✅ PASS
(jp synth)          JP_CLASS         valid 個人番号 · 個人番号手続 + 확인 → keep, clear  juminhyo          juminhyo          ✅ PASS
(jp synth)          JP_MYNUM_LEVEL   valid 個人番号 · 個人番号手続 + 확인 → keep, clear  keep              keep              ✅ PASS
(jp synth)          JP_MYNUM_NOTE    valid 個人番号 · 個人番号手続 + 확인 → keep, clear …(none)            (none)            ✅ PASS
(jp synth)          JP_MYNUM_BAND    valid 個人番号 · 個人番号手続 + 확인 → keep, clear …clear             clear             ✅ PASS
(jp synth)          JP_CLASS         valid 個人番号 · 個人番号手続 · 확인 없음 → gate, ban…juminhyo          juminhyo          ✅ PASS
(jp synth)          JP_MYNUM_LEVEL   valid 個人番号 · 個人番号手続 · 확인 없음 → gate, ban…gate              gate/mn_unconfirm…✅ PASS
(jp synth)          JP_MYNUM_NOTE    valid 個人番号 · 個人番号手続 · 확인 없음 → gate, ban…mn_unconfirmed    mn_unconfirmed    ✅ PASS
(jp synth)          JP_MYNUM_BAND    valid 個人番号 · 個人番号手続 · 확인 없음 → gate, ban…banded            banded            ✅ PASS
(jp synth)          JP_MYNUM_GEOM    valid 個人番号 · 個人番号手続 · 확인 없음 → gate, ban…masked            masked            ✅ PASS
(jp synth)          JP_CLASS         invalid check digit → recommend/checkdi…juminhyo          juminhyo          ✅ PASS
(jp synth)          JP_MYNUM_LEVEL   invalid check digit → recommend/checkdi…recommend         recommend/checkdi…✅ PASS
(jp synth)          JP_MYNUM_NOTE    invalid check digit → recommend/checkdi…checkdigit        checkdigit        ✅ PASS
(jp synth)          JP_MYNUM_BAND    invalid check digit → recommend/checkdi…banded            banded            ✅ PASS
(jp synth)          JP_MYNUM_GEOM    invalid check digit → recommend/checkdi…masked            masked            ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
(jp synth) 保険者名 과 保…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
(jp synth) 保険者名 과 保…JP_SYNTH         hokensha_bango                          level=auto kind=a…level=auto kind=a…✅ PASS
(jp synth) 保険者名 과 保…JP_SYNTH         hokensha_name                           level=keep kind=k…level=keep kind=k…✅ PASS
(jp synth) 保険者名 과 保…JP_SYNTH_MASK    99221010                                masked            masked            ✅ PASS
(jp synth) 保険者名 과 保…JP_SYNTH_MASK    架空健康保険協会                                clear             clear             ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
(jp synth) 保険者番号 라벨…JP_CLASS         shikaku_kakuninsho                      classified        shikaku_kakuninsh…✅ PASS
(jp synth) 保険者番号 라벨…JP_SYNTH         hokensha_bango                          level=auto kind=a…level=auto kind=a…✅ PASS
(jp synth) 保険者番号 라벨…JP_SYNTH         hokensha_name                           level=keep kind=k…level=keep kind=k…✅ PASS
(jp synth) 保険者番号 라벨…JP_SYNTH_MASK    99221010                                masked            masked            ✅ PASS
(jp synth) 保険者番号 라벨…JP_SYNTH_MASK    架空健康保険協会                                clear             clear             ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
(jp unlabelled)     JP_UNLABELLED    level                                   optional          optional          ✅ PASS
(jp unlabelled)     JP_UNLABELLED    default mode                            ok                ok                ✅ PASS
(jp unlabelled)     JP_UNLABELLED    not in default output                   0% covered        1%                ✅ PASS
(jp unlabelled)     JP_UNLABELLED    labelled code still banded              >=1 banded        banded ×1         ✅ PASS
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
(jp warn)           JP_WARN          資格確認書 제목 단독 (3점) → low confidence, 후보 띠…shown/lowconf     shown/lowconf     ✅ PASS
(jp warn)           JP_WARN_CLASS    資格確認書 제목 단독 (3점) → low confidence, 후보 띠…shikaku_kakuninshoshikaku_kakuninsh…✅ PASS
(jp warn)           JP_WARN_TEXT     資格確認書 제목 단독 (3점) → low confidence, 후보 띠…候補の黒塗りを既定で適用しました  matches           ✅ PASS
(jp warn)           JP_WARN_BANDS    資格確認書 제목 단독 (3점) → low confidence, 후보 띠…>=1               1                 ✅ PASS
(jp warn)           JP_WARN_NOAUTO   資格確認書 제목 단독 (3점) → low confidence, 후보 띠…(none)            (none)            ✅ PASS
(jp warn)           JP_WARN          免許証 언급만 (분류 불가) → 차단성 경고 + 띠 0          shown/unclassifiedshown/unclassified✅ PASS
(jp warn)           JP_WARN_CLASS    免許証 언급만 (분류 불가) → 차단성 경고 + 띠 0 class    null              null              ✅ PASS
(jp warn)           JP_WARN_TEXT     免許証 언급만 (분류 불가) → 차단성 경고 + 띠 0 banner t…自動黒塗りは適用していません    matches           ✅ PASS
(jp warn)           JP_WARN_BANDS    免許証 언급만 (분류 불가) → 차단성 경고 + 띠 0 bands in…0                 0                 ✅ PASS
(jp warn)           JP_WARN          和暦만 있는 일본어 이력서 → 경고 없음 (늑대소년 방지)        absent            absent            ✅ PASS
(jp warn)           JP_WARN_CLASS    和暦만 있는 일본어 이력서 → 경고 없음 (늑대소년 방지) class  null              null              ✅ PASS
(jp warn)           JP_WARN          日本語の特徴なし → 경고 없음                        absent            absent            ✅ PASS
(jp warn)           JP_WARN_CLASS    日本語の特徴なし → 경고 없음 class                  null              null              ✅ PASS
(jp warn)           JP_WARN          완전한 資格確認書 (4점 이상) → 경고 없음               absent            absent            ✅ PASS
(jp warn)           JP_WARN_CLASS    완전한 資格確認書 (4점 이상) → 경고 없음 class         shikaku_kakuninshoshikaku_kakuninsho✅ PASS
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
  REGRESSION         45 pass / 0 fail
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
  JP_WARN            14 pass / 0 fail
  JP_CLASS           27 pass / 0 fail
  JP_FIELD           16 pass / 0 fail
  JP_BANDED          41 pass / 0 fail
  JP_LEGAL           26 pass / 0 fail
  JP_AUTO_SET        20 pass / 0 fail
  JP_INK             15 pass / 0 fail
  JP_MASK            8 pass / 0 fail
  JP_CANDIDATE       27 pass / 0 fail
  JP_KEEP            47 pass / 0 fail
  JP_COVERAGE        15 pass / 0 fail
  JP_CLEAR           5 pass / 0 fail
  JP_MN_BOX          3 pass / 0 fail
  JP_MASK_OR_CAND    3 pass / 0 fail
  JP_OPTIONAL        4 pass / 0 fail
  JP_EMPTY           1 pass / 0 fail
  JP_ENTITIES        5 pass / 0 fail
  JP_MATRIX          1 pass / 0 fail
  JP_PAGECLASS       4 pass / 0 fail
  JP_BACK_ONLY       4 pass / 0 fail
  JP_BACK_COVER      3 pass / 0 fail
  JP_FRONT_CLEAR     4 pass / 0 fail
  JP_BACKANCHOR      2 pass / 0 fail
  JP_ATTACH_CLEAR    1 pass / 0 fail
  JP_ADDRESS         8 pass / 0 fail
  JP_TEL             6 pass / 0 fail
  JP_MYNUM_CD        8 pass / 0 fail
  JP_MYNUM_LEVEL     4 pass / 0 fail
  JP_MYNUM_NOTE      4 pass / 0 fail
  JP_MYNUM_BAND      4 pass / 0 fail
  JP_MYNUM_GEOM      3 pass / 0 fail
  JP_SYNTH           4 pass / 0 fail
  JP_SYNTH_MASK      4 pass / 0 fail
  JP_UNLABELLED      4 pass / 0 fail
  JP_WARN_CLASS      5 pass / 0 fail
  JP_WARN_TEXT       2 pass / 0 fail
  JP_WARN_BANDS      2 pass / 0 fail
  JP_WARN_NOAUTO     1 pass / 0 fail
  AI_INJECT          11 pass / 0 fail
  AI_CAT_STATE       2 pass / 0 fail
  CANDIDATE_DEDUP    2 pass / 0 fail
  CONFIRMED_SURVIVES 2 pass / 0 fail

  TOTAL: 533/533 pass, 0 FAIL

  ⚠ console errors:
    PageError: Failed to update a ServiceWorker for scope ('http://127.0.0.1:63358/safe/') with script ('Unknown'): Not found
exit=0
```
