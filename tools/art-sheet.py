"""그림 확인용 모음판. 사용: python tools/art-sheet.py <원본 폴더> <저장 png> <형태>..."""
import sys
from PIL import Image

src, out, forms = sys.argv[1], sys.argv[2], sys.argv[3:]
elements = ["fire", "ice", "storm", "poison", "steel", "abyss"]
sheet = Image.new("RGBA", (6 * 200, len(forms) * 200), (70, 74, 90, 255))
for r, form in enumerate(forms):
    for c, element in enumerate(elements):
        im = Image.open(f"{src}/{element}_{form}.png").convert("RGBA")
        if im.getpixel((5, 5))[3] != 0:
            print("not transparent", element, form)
        sheet.alpha_composite(im.resize((200, 200), Image.LANCZOS), (c * 200, r * 200))
sheet.save(out)
print("ok", out)
