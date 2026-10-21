# SafeFile JP 랜딩 3페이지 문안 v1 (2026-10-22) — JA 본문 + EN 병기 + KR 요지

> 공통 규칙: 사건명(タイムズカー) 불사용 · 「絶対/防ぐ/唯一」 불사용 · 모든 페이지에 「提出先の指示を必ず確認」 · 처리 화면에 광고 없음 · 법적 효과는 「制限される場合があります」 수준
> URL 제안: /safe/jp/nyusatsu/ · /safe/jp/honnin-kakunin/ · /safe/jp/ai-mae/  (safefile.net 확보 시 301)

---

## 페이지 1 — 入札添付の資格確認書マスキング (사업자용, 매출 축)

**title**: 入札添付の資格確認書・保険証コピー、番号だけ自動で黒塗り | SafeFile
**meta description**: 公共工事の入札で求められる被保険者記号・番号・保険者番号のマスキングを、ブラウザだけで自動処理。複数PDFを一括、ファイルはサーバーに送信しません。再提出をなくします。
**KR 요지**: 입찰 첨부 보험증 사본의 번호 마스킹을 브라우저에서 자동·일괄 처리. 서버 미전송. 반려 방지.

### H1
入札添付の資格確認書、番号だけを自動で黒塗り。再提出をなくす。

### リード
公共工事の入札では、健康保険の資格確認書や被保険者証の写しに「被保険者等記号・番号」「保険者番号」のマスキングが求められます（告知要求制限）。SafeFile は書類の種類を判定し、提出先ルールどおりの箇所だけを黒塗りします。氏名・生年月日・事業所名など、審査に必要な項目はそのまま残ります。

[今すぐ試す（無料・登録不要）]  [チームプランの資料を見る]

### なぜ手作業だと再提出になるのか（3点）
- 付箋や修正テープで隠した写しは、スキャン時に番号が透けることがある
- 画像編集アプリの黒塗りは「上に重ねただけ」で、PDF上で元の文字が残る場合がある
- 枝番や二次元コードを見落とすと、発注者側で差し戻しになる

### SafeFile が行うこと
| 書類 | 自動で黒塗り | 残す |
| --- | --- | --- |
| 資格確認書（被用者保険・国保・後期高齢） | 保険者番号・記号・番号・枝番・二次元コード | 氏名・生年月日・住所・有効期限・事業所名称 |
| 標準報酬決定通知書 | 被保険者整理番号 | 氏名・事業所名・対象月 |
| 住民票の写し | 個人番号・住民票コード（提出先が求めない場合） | 氏名・住所・発行者 |

※ 提出先の指示が優先です。指示と異なる場合は「残す項目」を個別に切り替えられます。

### 仕組み（3ステップ）
1. PDF・写真をドラッグ — 複数まとめて可
2. 「提出目的：入札添付」を選ぶ — 書類ごとに黒塗り箇所が自動で決まる
3. ダウンロード — 画像に平坦化され、黒塗りの下に原文は残りません。EXIF・注釈も削除

### 安全性
- ファイルはお使いのブラウザ内で処理され、サーバーには送信されません
- 出力はラスター化（画像化）。テキスト層・メタデータは含まれません
- 処理記録はブラウザ内のみ

### チームプラン（事業者向け）
月額 2,980円（税込）／年額 29,800円
- 提出先別プリセット（自治体・発注者ごとに保存）
- 複数PDFの一括処理・一括ダウンロード
- 処理記録（いつ・どの書類・どの目的）をCSVで
- SlimFile による容量圧縮を同時に（電子入札の容量制限対応）
- メールサポート（日本語）

**先行導入パイロット募集**：入札書類を月に複数件提出する建設業者・電子入札代行・行政書士の方、先着10社に3か月無料でご提供します。反映したい提出先ルールをお送りください。
[パイロットに申し込む] → フォーム（会社名・業種・月間提出件数・よく使う発注者・連絡先）

### よくある質問
- **マスキングしていない写しを出したらどうなりますか** — 多くの発注者は受付後に発注者側でマスキングしますが、再提出や差し戻しを求める自治体もあります。提出前の処理が確実です。
- **マイナ保険証しかありません** — 資格確認書または資格情報のお知らせの写しが対象です。マイナンバーカードの裏面は提出しないでください。
- **法律上の根拠は** — 健康保険法等の改正による告知要求制限（2020年10月1日施行）。医療保険事務以外の目的で記号・番号の告知を求めることは原則制限されています。

### EN (parallel)
**H1**: Redact only the numbers on insurance certificates for public tender attachments — and stop resubmissions.
**Lead**: Japanese public-works tenders require masking of the insured symbol/number and insurer number on health-insurance certificate copies. SafeFile detects the document type and blacks out exactly those fields, keeping name, date of birth and employer visible for review. Files never leave your browser.
**Team plan**: ¥2,980/month — per-recipient presets, batch PDF processing, processing log CSV, SlimFile compression, Japanese email support. Pilot: first 10 companies, 3 months free.

---

## 페이지 2 — 本人確認書類は「必要な面だけ」 (개인용, 트래픽)

**title**: 免許証・マイナンバーカードを送る前に — 必要な面だけ、不要な情報は黒塗り | SafeFile
**meta description**: 本人確認で求められていない情報まで送っていませんか。裏面・臓器提供欄・本籍など、提出先が求めない箇所だけを自動で黒塗り。登録不要、サーバー送信なし。
**KR 요지**: 본인확인 서류 최소화 원칙. 제출처가 요구하지 않는 면·항목만 가리기. 사건명 없음.

### H1
本人確認書類は「必要な面だけ」。求められていない情報は、送らない。

### リード
銀行・カード・通信・フリマの本人確認では、提出先が指定した面と項目だけで足ります。マイナンバーカードの裏面（個人番号）は身元確認には不要で、法令で認められた事務以外での複写・保管は制限される場合があります。SafeFile は書類を判定し、提出先が通常求めない箇所だけを黒塗りします。

### 書類別の目安（提出先の指示が優先）
| 書類 | 通常は送らない／黒塗り推奨 | 必ず残す |
| --- | --- | --- |
| マイナンバーカード | 裏面全体、表面の臓器提供欄 | 表面の氏名・住所・生年月日・有効期限・顔写真 |
| 運転免許証 | 裏面の備考欄（旧住所など）、臓器提供欄 | 表面すべて |
| 住民票の写し | 個人番号、本籍・筆頭者、本人以外の世帯員（求められない場合） | 氏名・住所・発行日・発行者 |
| 資格確認書 | 保険者番号・記号・番号・枝番・二次元コード | 氏名・生年月日・住所 |

### 「黒塗りしたつもり」が透ける理由
スマホの編集アプリで塗った黒は、半透明だったり、PDFの文字層が残っていたりします。SafeFile の出力は画像に平坦化され、黒塗りの下に原文は残りません。

### 使い方（30秒）
1. 写真かPDFをドラッグ
2. 「提出目的：本人確認提出」を選ぶ
3. 残す項目を確認してダウンロード

### これから変わること
2026年以降、スマートフォンのマイナンバーカードやICチップ読み取り（JPKI）による本人確認が広がり、画像での提出は減っていきます。画像提出が残る場面では、最小限の情報だけを送る習慣が自分を守ります。

### EN (parallel)
**H1**: Send only the side they need. Nothing more.
**Lead**: For KYC in Japan, the recipient's instructions decide what to submit. The back of the My Number card is not needed for identity checks and its copying may be restricted by law. SafeFile detects the document and blacks out only what recipients normally do not need, keeping everything they do.

---

## 페이지 3 — AIに貼り付ける前に黒塗り (신규 세그먼트, 패스 매출)

**title**: ChatGPT・Claudeに契約書や給与明細を貼る前に、個人情報だけ黒塗り | SafeFile
**meta description**: AIに相談するとき、相手の氏名・住所・口座・金額まで送っていませんか。相談に必要な文脈は残し、個人情報だけをブラウザ内で黒塗り。サーバー送信なし。
**KR 요지**: AI 상담 전 익명화. 상대방 정보·금액·계좌만 가리고 문맥은 유지.

### H1
AIに相談する前に、個人情報だけ黒塗り。文脈はそのまま。

### リード
賃貸借契約書、給与明細、請求書、診断書をAIに貼り付けて相談する人が増えています。便利ですが、貼り付けた文面には相手方の氏名・住所・口座番号・金額が含まれ、多くのAIサービスはその内容を保存します。SafeFile は「相談用共有」モードで、相談に不要な個人情報だけを黒塗りし、条文や数字の構造は残します。

### 相談用共有モードで黒塗りされるもの
- 相手方（貸主・保証人・取引先）の氏名・住所・電話
- 口座番号・残高・社員番号
- 印影・署名
- 自分の住所の番地以下（選択）

残るもの：契約条項、金額の相対関係、日付、見出し — AIが答えるのに必要な部分

### 使い方
1. PDF・写真をドラッグ
2. 「提出目的：相談用共有」を選ぶ
3. ダウンロードした画像をAIに貼り付け

### 30日パス 980円
制限なしで30日間。契約書を何通も見直す月だけ。サブスクではありません。
[無料で1枚試す]  [30日パスを買う]

### EN (parallel)
**H1**: Redact the personal data before you paste it into an AI. Keep the context.
**Lead**: People paste leases, payslips and invoices into ChatGPT or Claude for advice. Those pages carry the other party's name, address, bank account and amounts, and most AI services store what you paste. SafeFile's "share for advice" mode blacks out only the personal data and keeps the clauses and figures the AI needs.
**30-day pass ¥980** — unlimited for 30 days, no subscription.

---

## 파일럿 접촉 메일 (JA + EN + KR)

**件名**: 入札添付書類のマスキング、先着10社に3か月無料でご提供します（SafeFile）

○○株式会社 ご担当者様

突然のご連絡失礼いたします。Tasicop の Justin と申します。公共工事の入札で添付する資格確認書・被保険者証の写しについて、被保険者記号・番号・保険者番号の黒塗りをブラウザ内で自動処理するツール「SafeFile」を運営しています。

- 書類の種類を判定し、告知要求制限の対象箇所だけを黒塗り（氏名・事業所名は残ります）
- 複数PDFを一括処理、ファイルはサーバーに送信しません
- 出力は画像に平坦化され、黒塗りの下に原文が残りません

現在、入札書類を月に複数件提出されている事業者様を対象に、先着10社へチームプラン（通常月額2,980円）を3か月無料でご提供しています。お返事として「よく提出される発注者名」を1つお知らせいただければ、その発注者の指示に合わせたプリセットを用意してお送りします。

5分で試せます：https://slimfile.net/safe/jp/nyusatsu/

ご多忙のところ恐れ入りますが、ご検討いただければ幸いです。

Tasicop / Justin（成勲）
chaop2@gmail.com

**EN**: Subject: 3 months free for the first 10 companies — automatic redaction of tender attachment documents (SafeFile)
Dear Sir/Madam, I am Justin at Tasicop. SafeFile automatically redacts the insured symbol/number and insurer number on health-insurance certificate copies attached to public-works tenders, entirely in the browser. It detects the document type, blacks out only the fields subject to the disclosure restriction, processes multiple PDFs at once, and never uploads your files. Output is flattened to an image, so no original text remains under the black bars. We are offering the Team plan (normally ¥2,980/month) free for 3 months to the first 10 companies that submit tender documents monthly. Reply with the name of one contracting authority you submit to most, and we will prepare a preset matching its instructions. Try it in 5 minutes: https://slimfile.net/safe/jp/nyusatsu/ — Justin, Tasicop

**KR 요지**: 입찰 첨부 서류 자동 마스킹 툴 소개, 선착 10사 3개월 무료, 자주 내는 발주처 1곳만 회신하면 프리셋 제작.
