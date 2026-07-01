"""
Generuje ikonę aplikacji w stylu "flat road trip illustration".

Scena: niebieskie niebo ze słońcem i chmurami u góry, szare/niebieskie góry
w środku, zielona trawa z sosnami w dolnej części, czerwono-żółty samochód
z bagażem na dachu jadący po szarej drodze. Wszystko wkomponowane w
zaokrąglony kwadrat (adaptive-icon friendly).

Output:
- assets/icon/icon.png       — pełna ikona z tłem (Android legacy + Windows .ico)
- assets/icon/icon_fg.png    — sama scena bez tła (Android adaptive foreground)

Uruchomienie:
    python tools/generate_icon.py
"""
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024

# --- Paleta kolorów (flat illustration style) ---
SKY = (180, 222, 240, 255)              # jasny niebieski
SUN = (250, 232, 100, 255)              # żółte słońce
CLOUD = (255, 255, 255, 255)            # białe chmury
MOUNTAIN_BACK = (160, 175, 195, 255)    # tylne góry (jasniejsze)
MOUNTAIN_FRONT = (110, 130, 155, 255)   # przednie góry (ciemniejsze)
MOUNTAIN_SNOW = (240, 245, 250, 255)    # śnieg na szczycie
TREE_DARK = (50, 110, 70, 255)          # ciemne sosny
TREE_MID = (75, 145, 90, 255)           # jaśniejsze sosny
GRASS = (165, 210, 110, 255)            # zielona trawa
ROAD = (115, 110, 115, 255)             # szara droga
ROAD_EDGE = (95, 90, 95, 255)           # ciemniejsza krawędź drogi
CAR_RED = (215, 75, 65, 255)            # czerwone nadwozie
CAR_YELLOW = (245, 195, 65, 255)        # żółty środek
CAR_WINDOW = (135, 195, 215, 255)       # szyby
CAR_DARK = (60, 65, 80, 255)            # kontury, opony
LUGGAGE_BROWN = (135, 70, 55, 255)      # walizki
LUGGAGE_RACK = (220, 220, 225, 255)     # bagażnik
WHITE = (255, 255, 255, 255)

# Tło i ramka
BG_INSET = int(SIZE * 0.03)
BG_RADIUS = int(SIZE * 0.22)


def px(x, y):
    """(x_pct, y_pct) → (px, py) w skali SIZE."""
    return (int(x * SIZE), int(y * SIZE))


def main(out_path: str, out_fg_path: str) -> None:
    # Najpierw rysujemy całą scenę na pełnym canvasie, potem maskujemy.
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _paint_scene(canvas, with_background=True)

    # Maska zaokrąglonego kwadratu
    mask = Image.new("L", (SIZE, SIZE), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle(
        (BG_INSET, BG_INSET, SIZE - BG_INSET, SIZE - BG_INSET),
        radius=BG_RADIUS,
        fill=255,
    )
    masked = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    masked.paste(canvas, (0, 0), mask)
    masked.save(out_path, "PNG", optimize=True)
    print(f"Saved {out_path}")

    # Wersja foreground — bez nieba i trawy jako tła wypełniającego.
    # Tylko góry, sosny, droga i samochód (Android adaptive icon nakłada to
    # na tło zdefiniowane jako kolor w mipmap-anydpi-v26 — i tak nie wykorzysta
    # naszego nieba). Zostawiamy ją taką samą jak tła (transparentna), żeby
    # nie tworzyć drugiej, prostszej kompozycji — adaptive icon sam zamaskuje.
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _paint_scene(fg, with_background=False)
    fg.save(out_fg_path, "PNG", optimize=True)
    print(f"Saved {out_fg_path}")


def _paint_scene(canvas: Image.Image, with_background: bool) -> None:
    """Maluje scenę road-trip na podanym canvasie (cały SIZE×SIZE).

    `with_background=True` → wypełnia niebo i trawę.
    `with_background=False` → tylko elementy (góry/drzewa/auto/droga).
    """
    draw = ImageDraw.Draw(canvas)
    horizon_y = 0.58  # linia horyzontu — gdzie niebo styka się z trawą

    if with_background:
        # Niebo (cała górna część)
        draw.rectangle((0, 0, SIZE, int(horizon_y * SIZE)), fill=SKY)
        # Trawa (cała dolna część)
        draw.rectangle((0, int(horizon_y * SIZE), SIZE, SIZE), fill=GRASS)

    # Słońce
    sun_cx, sun_cy = px(0.78, 0.18)
    sun_r = int(SIZE * 0.075)
    draw.ellipse(
        (sun_cx - sun_r, sun_cy - sun_r, sun_cx + sun_r, sun_cy + sun_r),
        fill=SUN,
    )

    # Chmurki (po lewej i prawej od słońca)
    _draw_cloud(draw, cx=0.22, cy=0.20, scale=0.07)
    _draw_cloud(draw, cx=0.55, cy=0.15, scale=0.055)

    # Góry — najpierw tylne (jaśniejsze), potem przednie (ciemniejsze)
    # Tylna grupa: 2 góry
    _draw_mountain(draw, peak=(0.25, 0.32), base_l=(0.05, horizon_y), base_r=(0.45, horizon_y),
                   fill=MOUNTAIN_BACK, snow=False)
    _draw_mountain(draw, peak=(0.70, 0.28), base_l=(0.50, horizon_y), base_r=(0.95, horizon_y),
                   fill=MOUNTAIN_BACK, snow=False)
    # Przednia grupa: 3 góry z czapami śnieżnymi
    _draw_mountain(draw, peak=(0.40, 0.38), base_l=(0.15, horizon_y), base_r=(0.58, horizon_y),
                   fill=MOUNTAIN_FRONT, snow=True)
    _draw_mountain(draw, peak=(0.62, 0.34), base_l=(0.45, horizon_y), base_r=(0.78, horizon_y),
                   fill=MOUNTAIN_FRONT, snow=True)
    _draw_mountain(draw, peak=(0.85, 0.42), base_l=(0.70, horizon_y), base_r=(0.98, horizon_y),
                   fill=MOUNTAIN_FRONT, snow=False)

    # Droga — pas po przekątnej-poziomy w dolnej części
    road_y_top = 0.72
    road_y_bot = 0.83
    draw.polygon(
        [px(0.0, road_y_top + 0.02), px(1.0, road_y_top), px(1.0, road_y_bot), px(0.0, road_y_bot + 0.02)],
        fill=ROAD,
    )
    # Krawędzie drogi (cienkie ciemne pasy)
    edge_h = int(SIZE * 0.007)
    draw.polygon(
        [px(0.0, road_y_top + 0.02), px(1.0, road_y_top),
         px(1.0, road_y_top + 0.012), px(0.0, road_y_top + 0.032)],
        fill=ROAD_EDGE,
    )

    # Sosny na trawie po bokach (przed samochodem i za nim)
    # Lewa strona — większa sosna na pierwszym planie
    _draw_pine(draw, base=(0.10, 0.72), height=0.18, width=0.07, fill=TREE_DARK)
    # Prawa strona — kilka sosen w głębi i jedna duża na pierwszym planie
    _draw_pine(draw, base=(0.90, 0.72), height=0.18, width=0.07, fill=TREE_DARK)
    _draw_pine(draw, base=(0.78, 0.68), height=0.12, width=0.05, fill=TREE_MID)
    _draw_pine(draw, base=(0.18, 0.69), height=0.13, width=0.052, fill=TREE_MID)

    # SAMOCHÓD na środku drogi (najważniejszy element)
    _draw_car(draw, cx=0.50, cy=0.74)

    # Krzaki przy samochodzie (przedni plan, jak na inspiracji)
    _draw_bush(draw, cx=0.34, cy=0.88, w=0.08, h=0.04)
    _draw_bush(draw, cx=0.68, cy=0.90, w=0.10, h=0.045)


def _draw_cloud(draw: ImageDraw.ImageDraw, *, cx: float, cy: float, scale: float) -> None:
    """Rysuje białą chmurkę z 3 nakładających się okręgów."""
    r1 = int(SIZE * scale)
    r2 = int(SIZE * scale * 0.85)
    r3 = int(SIZE * scale * 0.75)
    c = px(cx, cy)
    draw.ellipse((c[0] - r1, c[1] - r1, c[0] + r1, c[1] + r1), fill=CLOUD)
    draw.ellipse((c[0] - 2 * r1, c[1] - r3, c[0], c[1] + r3), fill=CLOUD)
    draw.ellipse((c[0], c[1] - r2, c[0] + 2 * r2, c[1] + r2), fill=CLOUD)


def _draw_mountain(draw, *, peak, base_l, base_r, fill, snow: bool) -> None:
    """Trójkątna góra z opcjonalnym śnieżnym czubkiem."""
    poly = [px(*base_l), px(*peak), px(*base_r)]
    draw.polygon(poly, fill=fill)

    if snow:
        # Czapa śnieżna — 12% wysokości w dół wzdłuż obu zboczy.
        height = max(base_l[1], base_r[1]) - peak[1]
        drop = height * 0.14
        # Punkty na zboczach w odległości `drop` pionowo od szczytu.
        t_left = drop / (base_l[1] - peak[1]) if base_l[1] > peak[1] else 0
        t_right = drop / (base_r[1] - peak[1]) if base_r[1] > peak[1] else 0
        snow_l = (peak[0] + (base_l[0] - peak[0]) * t_left, peak[1] + drop)
        snow_r = (peak[0] + (base_r[0] - peak[0]) * t_right, peak[1] + drop)
        draw.polygon([px(*peak), px(*snow_l), px(*snow_r)], fill=MOUNTAIN_SNOW)


def _draw_pine(draw, *, base: tuple, height: float, width: float, fill) -> None:
    """Trójkątna sosna — 2 nakładające się trójkąty dla efektu 'choinki'."""
    bx, by = base
    # Dolny trójkąt (szerszy)
    top1 = (bx, by - height * 0.55)
    bl1 = (bx - width / 2, by)
    br1 = (bx + width / 2, by)
    draw.polygon([px(*bl1), px(*top1), px(*br1)], fill=fill)
    # Górny trójkąt (węższy, wyżej)
    top2 = (bx, by - height)
    bl2 = (bx - width * 0.4, by - height * 0.45)
    br2 = (bx + width * 0.4, by - height * 0.45)
    draw.polygon([px(*bl2), px(*top2), px(*br2)], fill=fill)


def _draw_bush(draw, *, cx: float, cy: float, w: float, h: float) -> None:
    """Krzak — 3 nakładające się okręgi w ciemnozielonym."""
    cx_px, cy_px = px(cx, cy)
    rw = int(w * SIZE / 2)
    rh = int(h * SIZE)
    color = (45, 95, 60, 255)
    # Lewa, środkowa (większa), prawa kula
    draw.ellipse((cx_px - rw, cy_px - rh // 2, cx_px - rw // 3, cy_px + rh // 2), fill=color)
    draw.ellipse((cx_px - rw // 2, cy_px - rh, cx_px + rw // 2, cy_px + rh // 2), fill=color)
    draw.ellipse((cx_px + rw // 3, cy_px - rh // 2, cx_px + rw, cy_px + rh // 2), fill=color)


def _draw_car(draw, *, cx: float, cy: float) -> None:
    """Auto osobowe (kombi/SUV) z BOKU, w stylu flat illustration.

    Sylwetka: żółte dolne nadwozie + czerwona kabina trapezoidalna (skosy
    przednia/tylna szyba), 2 niebieskie szyby, bagażnik dachowy z walizką,
    2 koła z felgami, linia drzwi, reflektor z przodu.

    `cx`, `cy` = środek auta na canvasie (procent SIZE).
    """
    cw = SIZE * 0.36                   # szerokość auta (poziom)
    body_h = SIZE * 0.07               # wysokość dolnego nadwozia
    cabin_h = SIZE * 0.058             # wysokość kabiny
    cx_px = cx * SIZE
    cy_px = cy * SIZE                  # cy = środek auta między dachem a kołami

    # --- Dolne nadwozie (żółte) ---
    body_left = cx_px - cw / 2
    body_right = cx_px + cw / 2
    body_top = cy_px - body_h / 2
    body_bot = cy_px + body_h / 2
    draw.rounded_rectangle(
        (body_left, body_top, body_right, body_bot),
        radius=int(SIZE * 0.020),
        fill=CAR_YELLOW,
    )

    # --- Kabina (czerwona, trapezoidalna — skosy szyb) ---
    # Kabina jest węższa od nadwozia i osadzona bliżej środka-tyłu auta
    # (typowy SUV: krótsza maska, dłuższa kabina). "Przód" auta jest po prawej.
    cabin_inset_front = cw * 0.20      # od prawej (maska)
    cabin_inset_back = cw * 0.08       # od lewej (tylny zwis)
    cabin_left = body_left + cabin_inset_back
    cabin_right = body_right - cabin_inset_front
    cabin_top = body_top - cabin_h
    cabin_bot = body_top + 1            # 1px nakładki, żeby nie było szpary

    skos = cw * 0.045
    cabin_poly = [
        (cabin_left, cabin_bot),
        (cabin_left + skos, cabin_top),         # skos tylnej szyby
        (cabin_right - skos, cabin_top),        # skos przedniej szyby
        (cabin_right, cabin_bot),
    ]
    draw.polygon(cabin_poly, fill=CAR_RED)

    # --- Szyby (jasnoniebieskie, 2 — przednia i tylna) ---
    win_pad_top = cabin_h * 0.20
    win_pad_bot = cabin_h * 0.12
    win_pad_side = cw * 0.015
    win_split_w = cw * 0.012            # czerwony słupek B między oknami

    win_top_y = cabin_top + win_pad_top
    win_bot_y = cabin_bot - win_pad_bot
    win_mid_x = (cabin_left + cabin_right) / 2

    # Lewe okno (tylne, z trapezoidalnym skosem po lewej)
    win_l_poly = [
        (cabin_left + win_pad_side, win_bot_y),
        (win_mid_x - win_split_w, win_bot_y),
        (win_mid_x - win_split_w, win_top_y),
        (cabin_left + skos + win_pad_side * 0.8, win_top_y),
    ]
    draw.polygon(win_l_poly, fill=CAR_WINDOW)

    # Prawe okno (przednie, z trapezoidalnym skosem po prawej)
    win_r_poly = [
        (win_mid_x + win_split_w, win_bot_y),
        (cabin_right - win_pad_side, win_bot_y),
        (cabin_right - skos - win_pad_side * 0.8, win_top_y),
        (win_mid_x + win_split_w, win_top_y),
    ]
    draw.polygon(win_r_poly, fill=CAR_WINDOW)

    # --- Bagażnik dachowy + walizka ---
    rack_y = cabin_top - SIZE * 0.005
    rack_h = int(SIZE * 0.009)
    draw.rounded_rectangle(
        (cabin_left + cw * 0.04, rack_y, cabin_right - cw * 0.04, rack_y + rack_h),
        radius=int(rack_h * 0.4),
        fill=LUGGAGE_RACK,
    )
    # Jedna walizka (centralnie na bagażniku) — jak na inspiracji
    lug_h = int(SIZE * 0.035)
    lug_w = int(cw * 0.40)
    lug_left = int(cabin_left + cw * 0.18)
    lug_bot = rack_y - int(rack_h * 0.2)
    lug_top = lug_bot - lug_h
    draw.rounded_rectangle(
        (lug_left, lug_top, lug_left + lug_w, lug_bot),
        radius=int(SIZE * 0.006),
        fill=LUGGAGE_BROWN,
    )
    # Pasek na walizce (jaśniejszy)
    band_y = lug_top + int(lug_h * 0.55)
    draw.rectangle(
        (lug_left, band_y, lug_left + lug_w, band_y + int(lug_h * 0.10)),
        fill=(165, 90, 70, 255),
    )

    # --- Linia drzwi (cienka, pionowa, na żółtym nadwoziu) ---
    door_x = int(cx_px - cw * 0.03)
    draw.line(
        [(door_x, body_top + body_h * 0.18), (door_x, body_bot - body_h * 0.18)],
        fill=(170, 130, 40, 255),
        width=3,
    )

    # --- Reflektor (mały żółty owal z prawej, przedni) ---
    light_w = int(SIZE * 0.020)
    light_h = int(SIZE * 0.010)
    light_x = int(body_right - cw * 0.025)
    light_y = int(cy_px - body_h * 0.05)
    draw.ellipse(
        (light_x - light_w, light_y - light_h, light_x, light_y + light_h),
        fill=(255, 250, 180, 255),
    )

    # --- Koła (2, widoczne z boku) ---
    wheel_r = int(SIZE * 0.040)
    wheel_y = int(body_bot + wheel_r * 0.15)
    front_wheel_x = int(body_right - cw * 0.16)
    back_wheel_x = int(body_left + cw * 0.16)
    for wx in (back_wheel_x, front_wheel_x):
        # Opona — czarny okrąg
        draw.ellipse(
            (wx - wheel_r, wheel_y - wheel_r, wx + wheel_r, wheel_y + wheel_r),
            fill=CAR_DARK,
        )
        # Felga — jasny środek
        inner = int(wheel_r * 0.45)
        draw.ellipse(
            (wx - inner, wheel_y - inner, wx + inner, wheel_y + inner),
            fill=(220, 220, 225, 255),
        )


if __name__ == "__main__":
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    project = os.path.dirname(here)
    out = os.path.join(project, "assets", "icon", "icon.png")
    out_fg = os.path.join(project, "assets", "icon", "icon_fg.png")
    main(out, out_fg)
