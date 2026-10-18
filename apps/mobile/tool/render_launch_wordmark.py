"""Renders the Android launch-screen wordmark (android/app/src/main/res/drawable-*/launch_wordmark.png).

"La Nonna" in Baloo 2 ExtraBold, AppColors.primaryDark: the same style as the
app's logo mark (OnboardingLogoMark, headlineLarge). The canvas is the Android 12+
splash icon size (288 dp) with the text inside its 192 dp safe circle.

Usage (Pillow; font is OFL, from github.com/google/fonts ofl/baloo2/Baloo2[wght].ttf):
  python3 tool/render_launch_wordmark.py   # with Baloo2.ttf in the working directory
then copy launch_wordmark_<density>.png to res/drawable-<density>/launch_wordmark.png.
"""
from PIL import Image, ImageDraw, ImageFont
# Android 12+ splash icon canvas: 288dp; wordmark kept inside the 192dp safe circle.
DENS = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
COLOR = (0x7F, 0xAE, 0x6E, 255)  # AppColors.primaryDark (headlineLarge)
for name, d in DENS.items():
    S = round(288 * d); target_w = 168 * d
    size = 10
    while True:
        f = ImageFont.truetype('Baloo2.ttf', size); f.set_variation_by_axes([800])
        if f.getbbox('La Nonna')[2] - f.getbbox('La Nonna')[0] > target_w: break
        size += 1
    f = ImageFont.truetype('Baloo2.ttf', size - 1); f.set_variation_by_axes([800])
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0)); dr = ImageDraw.Draw(img)
    x0, y0, x1, y1 = dr.textbbox((0, 0), 'La Nonna', font=f)
    dr.text(((S - (x1 - x0)) / 2 - x0, (S - (y1 - y0)) / 2 - y0), 'La Nonna', font=f, fill=COLOR)
    img.save(f'launch_wordmark_{name}.png', optimize=True)
    print(name, S, size - 1, (x1 - x0, y1 - y0))
