𝗧𝗵𝗲 𝗌𝗮𝗺𝗲 𝗱𝗼𝗰𝗎𝗺𝗲𝗻𝗍, 𝗍𝗎𝗼 𝗳𝗼𝗿𝗺𝗌, 𝗼𝗻𝗲 𝗊𝗶𝗍𝗵 𝗮 𝗻𝗮𝗍𝗶𝗼𝗻𝗮𝗹 𝗶𝗱 𝗻𝗎𝗺𝗯𝗲𝗿 𝗼𝗻 𝗶𝗍.

I'm building SafeFile, a browser-only tool that covers personal details in a document.

A Japanese withholding slip is the annual income statement. You hand a copy to a bank, a nursery, a landlord. There are two versions of it. The one your employer gives you generally has no national ID number. The one they file with the tax office can.

Employers sometimes hand you the filing version as your copy.

So "does this document contain an ID number?" has no answer at the document-type level. Only the sheet in front of you knows.

That broke an assumption in my detector. I had a map from document type to the fields it contains, and it is wrong for a whole class of documents — the same name covers two layouts.

Two things I changed:

1. The type no longer decides what exists. It decides what to look for. Whether a field is there is answered by looking.

2. The article says "check the sheet" rather than "this document is safe". I can't make the second statement true, so I stopped making it.

It's free and still rough. If you've been handed the wrong version of a form, I'd like to hear it.

https://slimfile.net/en/blog/jp-ep07-withholding-slips-when-a-my-number-is-pr?via=linkedin&ep=ep07

#buildinpublic #privacy #sideproject
