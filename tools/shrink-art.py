"""art/dragons-src의 원본을 256px 게임용 그림으로 줄인다. 사용: python tools/shrink-art.py <원본 폴더> <id>..."""
import sys
from PIL import Image

src = sys.argv[1]
for name in sys.argv[2:]:
    im = Image.open(f"{src}/{name}.png").convert("RGBA")
    box = im.getbbox()
    side = max(box[2] - box[0], box[3] - box[1])
    pad = int(side * 0.04)
    canvas = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    crop = im.crop(box)
    canvas.alpha_composite(crop, ((canvas.width - crop.width) // 2, (canvas.height - crop.height) // 2))
    canvas.resize((256, 256), Image.LANCZOS).save(f"assets/dragons/{name}.png")
    im.save(f"art/dragons-src/{name}.png")
    print("ok", name)
