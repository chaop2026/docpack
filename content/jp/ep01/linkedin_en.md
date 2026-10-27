𝗧𝗵𝗶𝘀 𝘄𝗲𝗲𝗸 𝗜 𝘀𝗵𝗶𝗽𝗽𝗲𝗱 𝗽𝘂𝗿𝗽𝗼𝘀𝗲-𝗯𝗮𝘀𝗲𝗱 𝗿𝗲𝗱𝗮𝗰𝘁𝗶𝗼𝗻 𝗳𝗼𝗿 𝗝𝗮𝗽𝗮𝗻𝗲𝘀𝗲 𝗜𝗗 𝗱𝗼𝗰𝘂𝗺𝗲𝗻𝘁𝘀.

SafeFile is a side project: a browser-only tool that finds personal data in a document and covers it with black bars. Nothing is uploaded. I had treated "what to hide" as a per-field choice — for Japanese documents that was the wrong unit.

Three things I learned:

— The rule is per recipient, not per field. The same insurance certificate needs different bars for a tender, an ID check, or an AI chat. So the UI now asks "what is this for?" and derives the mask set from that, instead of 12 toggles.

— A black rectangle in a PDF is often not a redaction; the text layer underneath copies out fine. The only output I trust is a flattened raster, so that's the only output — EXIF and annotations go with it.

— What people miss is never the big number. It's the 2-digit branch code and the QR code, which encode the same identifier. The classifier now treats them as one group.

It's live, free and rough. If you handle documents like this, or you've built redaction before and think I got something wrong, ten minutes of feedback beats a share.

https://slimfile.net/en/blog/jp-ep01-how-to-redact-the-numbers-on-a-qualifica?utm_source=linkedin&utm_medium=social&utm_campaign=ep01

#buildinpublic #privacy #rails
