from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
FONT_REGULAR = Path(r"C:\Windows\Fonts\msyh.ttc")
FONT_BOLD = Path(r"C:\Windows\Fonts\msyhbd.ttc")


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT_REGULAR
    return ImageFont.truetype(str(path), size=size)


def draw_lines(
    draw: ImageDraw.ImageDraw,
    lines: Iterable[tuple[str, int, bool, str]],
    x: int,
    y: int,
    spacing: int = 28,
) -> int:
    cursor = y
    for text, size, bold, color in lines:
        draw.text((x, cursor), text, font=font(size, bold), fill=color)
        cursor += size + spacing
    return cursor


def base_canvas(height: int, accent: str) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (1080, height), "#F4F1E9")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((54, 58, 1026, height - 58), radius=38, fill="#FFFDF8", outline="#DDD5C7", width=3)
    draw.rounded_rectangle((54, 58, 1026, 180), radius=38, fill=accent)
    draw.rectangle((54, 130, 1026, 180), fill=accent)
    return image, draw


def poster() -> Image.Image:
    image, draw = base_canvas(1600, "#2E5547")
    draw.text((104, 92), "校园活动 · 讲座海报", font=font(34, True), fill="#FFFDF8")
    draw_lines(draw, [
        ("人工智能前沿讲座", 68, True, "#22221F"),
        ("从多模态模型到智能体", 42, False, "#6B675F"),
    ], 104, 250, 34)
    draw.rounded_rectangle((104, 520, 976, 940), radius=30, fill="#EEF4EF")
    draw_lines(draw, [
        ("时间", 30, True, "#A65B24"),
        ("2026年7月25日 14:00", 48, True, "#27332D"),
        ("地点", 30, True, "#A65B24"),
        ("图书馆报告厅", 48, True, "#27332D"),
    ], 154, 580, 28)
    draw_lines(draw, [
        ("主讲人：陈教授", 38, False, "#3F3D38"),
        ("主办：计算机学院", 34, False, "#77736A"),
    ], 104, 1050, 32)
    return image


def pickup() -> Image.Image:
    image, draw = base_canvas(1440, "#E88932")
    draw.text((104, 92), "菜鸟驿站 · 取件通知", font=font(34, True), fill="#FFFDF8")
    draw.text((104, 270), "您的快递已到站", font=font(58, True), fill="#26231F")
    draw.rounded_rectangle((104, 440, 976, 790), radius=34, fill="#FFF0DA", outline="#E8B275", width=3)
    draw.text((154, 505), "取件码", font=font(34, True), fill="#8A4A18")
    draw.text((154, 600), "A8B6", font=font(108, True), fill="#2A2925")
    draw_lines(draw, [
        ("地点：南门快递站", 42, True, "#3B3933"),
        ("请于7月23日前领取", 38, False, "#6D685F"),
    ], 104, 900, 34)
    return image


def ddl() -> Image.Image:
    image, draw = base_canvas(1800, "#445A78")
    draw.text((104, 92), "教学平台 · DDL 通知", font=font(34, True), fill="#FFFDF8")
    draw.text((104, 260), "课程作业通知", font=font(62, True), fill="#252526")
    draw.text((104, 370), "数据库课程设计", font=font(46, False), fill="#5E6270")
    draw.rounded_rectangle((104, 540, 976, 980), radius=30, fill="#EEF1F7")
    draw_lines(draw, [
        ("截止时间", 32, True, "#395074"),
        ("2026年7月28日 23:59", 50, True, "#262D38"),
        ("提交地点", 32, True, "#395074"),
        ("教学平台", 48, True, "#262D38"),
    ], 154, 610, 30)
    draw_lines(draw, [
        ("请提交项目报告与源代码", 38, False, "#3D3D3A"),
        ("逾期提交将扣除成绩", 34, False, "#9A4438"),
    ], 104, 1110, 34)
    return image


def coupon() -> Image.Image:
    image, draw = base_canvas(1350, "#9B3E4E")
    draw.text((104, 92), "校园咖啡 · 优惠券", font=font(34, True), fill="#FFFDF8")
    draw.text((104, 260), "满30减10元", font=font(76, True), fill="#8D2E40")
    draw.text((104, 380), "堂食与外带均可使用", font=font(36, False), fill="#6A625D")
    draw.rounded_rectangle((104, 540, 976, 905), radius=30, fill="#FFF0F2", outline="#E6B4BD", width=3)
    draw_lines(draw, [
        ("有效期至", 32, True, "#8D2E40"),
        ("2026年7月31日 23:59", 48, True, "#3A292C"),
        ("地点：学生活动中心一层", 38, False, "#544A4C"),
    ], 154, 610, 30)
    return image


def main() -> None:
    samples = {
        "poster.png": poster(),
        "pickup-code.png": pickup(),
        "ddl-notice.png": ddl(),
        "coupon.png": coupon(),
    }
    for filename, image in samples.items():
        image.save(ROOT / filename, format="PNG", optimize=False)


if __name__ == "__main__":
    main()
