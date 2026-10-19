"""Build static, subset app fonts from Google Fonts sources.

Usage:
    uv run --with fonttools python -I tool/fonts/build_fonts.py <src_dir> assets/fonts

<src_dir> holds google/fonts `ofl/<family>/` downloads (literata, notoserif,
ptserif, manrope) and `lora-static/` with the static TTFs from
github.com/cyrealtype/Lora-Cyrillic (fonts/ttf/).

Variable fonts are pinned to static instances (Flutter does not map
FontWeight to the wght axis reliably), then subset to Latin, Cyrillic,
Greek, combining accents (Russian stress marks) and punctuation.

Lora and PT Serif have Reserved Font Names in their OFL licenses, so a
modified copy may not keep the name: these are copied unmodified.
"""

import shutil
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

UNICODES = (
    list(range(0x0020, 0x0250))  # Basic Latin .. Latin Extended-B
    + list(range(0x0300, 0x0370))  # combining marks (stress U+0301)
    + list(range(0x0370, 0x0400))  # Greek
    + list(range(0x0400, 0x0530))  # Cyrillic + Supplement
    + list(range(0x1E00, 0x1F00))  # Latin Extended Additional
    + list(range(0x2000, 0x2070))  # General Punctuation
    + list(range(0x20A0, 0x20D0))  # currency
    + list(range(0x2100, 0x2150))  # letterlike (№)
    + list(range(0x2190, 0x2200))  # arrows
    + list(range(0x2200, 0x2300))  # math operators
    + [0x00A0, 0x25CC, 0xFEFF, 0xFFFD]
)

# (output name, source file, axes to pin, None to subset a static font,
# or COPY to ship the file unmodified)
COPY = 'copy'
JOBS = [
    ('Literata-Regular', 'literata/Literata[opsz,wght].ttf', {'wght': 400, 'opsz': 12}),
    ('Literata-Bold', 'literata/Literata[opsz,wght].ttf', {'wght': 700, 'opsz': 12}),
    ('Literata-Italic', 'literata/Literata-Italic[opsz,wght].ttf', {'wght': 400, 'opsz': 12}),
    ('Literata-BoldItalic', 'literata/Literata-Italic[opsz,wght].ttf', {'wght': 700, 'opsz': 12}),
    ('Lora-Regular', 'lora-static/Lora-Regular.ttf', COPY),
    ('Lora-Bold', 'lora-static/Lora-Bold.ttf', COPY),
    ('Lora-Italic', 'lora-static/Lora-Italic.ttf', COPY),
    ('Lora-BoldItalic', 'lora-static/Lora-BoldItalic.ttf', COPY),
    ('NotoSerif-Regular', 'notoserif/NotoSerif[wdth,wght].ttf', {'wght': 400, 'wdth': 100}),
    ('NotoSerif-Bold', 'notoserif/NotoSerif[wdth,wght].ttf', {'wght': 700, 'wdth': 100}),
    ('NotoSerif-Italic', 'notoserif/NotoSerif-Italic[wdth,wght].ttf', {'wght': 400, 'wdth': 100}),
    ('NotoSerif-BoldItalic', 'notoserif/NotoSerif-Italic[wdth,wght].ttf', {'wght': 700, 'wdth': 100}),
    ('PTSerif-Regular', 'ptserif/PT_Serif-Web-Regular.ttf', COPY),
    ('PTSerif-Bold', 'ptserif/PT_Serif-Web-Bold.ttf', COPY),
    ('PTSerif-Italic', 'ptserif/PT_Serif-Web-Italic.ttf', COPY),
    ('PTSerif-BoldItalic', 'ptserif/PT_Serif-Web-BoldItalic.ttf', COPY),
    ('Manrope-Regular', 'manrope/Manrope[wght].ttf', {'wght': 400}),
    ('Manrope-SemiBold', 'manrope/Manrope[wght].ttf', {'wght': 600}),
    ('Manrope-Bold', 'manrope/Manrope[wght].ttf', {'wght': 700}),
]


def main(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    options = subset.Options()
    options.layout_features = ['*']
    options.name_IDs = ['*']
    options.name_languages = ['*']
    options.notdef_outline = True
    options.glyph_names = False
    for name, source, axes in JOBS:
        target = out / f'{name}.ttf'
        if axes == COPY:
            shutil.copyfile(src / source, target)
            print(f'{target.name}: {target.stat().st_size // 1024} KB (unmodified)')
            continue
        font = TTFont(src / source)
        if axes is not None:
            font = instancer.instantiateVariableFont(font, axes)
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=UNICODES)
        subsetter.subset(font)
        font.save(target)
        print(f'{target.name}: {target.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main(Path(sys.argv[1]), Path(sys.argv[2]))
