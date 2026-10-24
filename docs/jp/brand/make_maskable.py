"""public/safe/brand/icon-maskable-512.png

A maskable icon is NOT the same image as the app icon. The platform crops it to
an arbitrary shape (circle, squircle, rounded square) and only the inner 80%
— the "safe zone" — is guaranteed to survive. Dropping the brand mark straight
in would get its edges shaved off on Android.

So: full-bleed INK background (the crop can never reach past it), with the brand
tile scaled to 80% and centred. Derived from the committed brand icon rather
than redrawn, so the two cannot drift apart.
"""
from PIL import Image

INK = (0x1A, 0x16, 0x13, 255)
SIZE = 512
SAFE = 0.80

src = Image.open("public/safe/brand/icon-512.png").convert("RGBA")
inner = round(SIZE * SAFE)
scaled = src.resize((inner, inner), Image.LANCZOS)

out = Image.new("RGBA", (SIZE, SIZE), INK)
off = (SIZE - inner) // 2
out.alpha_composite(scaled, (off, off))
out.save("public/safe/brand/icon-maskable-512.png")
print(f"public/safe/brand/icon-maskable-512.png {out.size[0]}x{out.size[1]} (safe zone {int(SAFE*100)}%)")
