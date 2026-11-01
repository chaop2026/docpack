---
title: Handling e-tender PDF size limits and redaction in the right order
hook: The upload was rejected minutes before the deadline, and the redaction had to be redone.
cta: Try redacting a certificate in the browser
bullets:
  - The size cap is set by the contracting body — 5MB, 10MB and 50MB all exist
  - Flattening a redaction to a picture can make the file bigger or smaller
  - Redact first and check the size last, and you redo less work
x_reply: "Japanese e-tender portals cap attachment size, and the cap differs by authority. Redact first, check the size last:"
---

Attachments to an electronic tender have a size cap. Hit it at the last minute and the redaction often has to be done again.

That rework comes from doing the two jobs in the wrong order. Compress first, redact second, and flattening changes the size again — so you are back over the cap with the redaction already finished.

## The cap is not one number

| How the instruction reads | Cap | Watch for |
| --- | --- | --- |
| total file size within 10MB | 10MB combined | often printed next to "more than one file is not accepted" |
| attachments per message within 5MB | 5MB per message | common where submission is by email |
| attachment size raised to 50MB | 50MB | a portal-side specification change |

Same phrase, "electronic tender", and the number differs by a factor of ten. It has to be read per notice. Some instructions allow compression — ZIP, if that brings it under the cap, sometimes with self-extracting archives excluded.

Combining several documents into one file is something the instruction tells you to do; it is not what this tool does. This tool redacts one file.

## Redact, then check the size

1. Drop in the PDF or the photo of the certificate.
2. Choose "purpose: tender attachment". What to cover is decided for you.
3. Download, then check that file's size. The output is flattened to a picture, so a text PDF can come out larger — and a phone photo can come out smaller.

If it is over, lower the scan resolution or check whether the instruction allows compression. The redaction does not need redoing.

## Why

The Kanto Regional Development Bureau's bid instructions say that application documents must be combined into a single file, that more than one file is not accepted, and that the total must be within 10MB — adding that ZIP or LZH compression is accepted where that brings it under, excluding self-extracting archives. Other instructions set 5MB per message.

Source: MLIT Kanto Regional Development Bureau, "Bid instructions (common items), as of 1 April 2026" https://www.ktr.mlit.go.jp/ktr_content/content/000941342.pdf (Confirmed: 2026-11-01)

Always check the recipient's own instructions.

Files are processed inside the browser and are not sent to a server.
