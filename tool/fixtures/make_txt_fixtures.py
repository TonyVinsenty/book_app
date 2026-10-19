"""Builds the small TXT books in test/fixtures/txt/ (different encodings and
layouts). Run from the project root: python tool/fixtures/make_txt_fixtures.py
The texts are written for the tests, no copyright."""

import pathlib
import textwrap

OUT = pathlib.Path('test/fixtures/txt')

PARAS_RU = [
    'Утро было тихим, и над рекой ещё стоял туман. Анна вышла на крыльцо, '
    'посмотрела на дорогу и решила, что гости приедут не раньше полудня.',
    '— Ты опять встала раньше всех? — спросил отец из глубины дома.',
    '— Как обычно, — ответила она. — Кто-то же должен ставить самовар.',
    'В 1812 г. в этом доме стоял полк, и с тех пор на стене висела старая '
    'карта с пометками какого-нибудь штабного писаря, выцветшими от '
    'времени и солнца.',
]

PARAS_RU_2 = [
    'К вечеру приехал доктор Петров, а за ним и т. д. — вся родня, о '
    'которой Анна думала с утра. Разговоры шли о погоде, о ценах и о '
    'том, что лето в этом году выдалось на удивление долгим.',
    'Ночью пошёл дождь. Он стучал по крыше ровно и спокойно, будто '
    'читал вслух длинную книгу, которую никто не собирался дослушать до '
    'конца.',
]


def write(name: str, data: bytes) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_bytes(data)


def wrapped(paras, width, indent):
    lines = []
    for p in paras:
        wrapped_lines = textwrap.wrap(p, width=width - len(indent),
                                      break_on_hyphens=False)
        lines.append(indent + wrapped_lines[0])
        lines.extend(wrapped_lines[1:])
    return lines


def main() -> None:
    # Modern file: one line per paragraph, UTF-8, LF.
    text = '\n'.join(
        ['Глава 1', *PARAS_RU, '* * *', 'Глава 2', *PARAS_RU_2]) + '\n'
    write('utf8_lines.txt', text.encode('utf-8'))

    # English, UTF-8 with BOM, CRLF, blank lines between paragraphs.
    en = [
        'Chapter 1',
        'The morning was quiet. Mr. Brown opened the window, looked at the '
        'road and decided that the guests would not come before noon.',
        '"Up again before everyone?" asked his father.',
        'Chapter 2',
        'By evening the doctor arrived, e.g. the usual crowd followed.',
    ]
    write('utf8_bom_crlf.txt',
          b'\xef\xbb\xbf' + '\r\n\r\n'.join(en).encode('utf-8') + b'\r\n')

    # Old lib.ru style: Windows-1251, CRLF, lines cut at ~70 chars,
    # paragraphs start with an indent, a hyphen split across lines.
    lines = ['ЧАСТЬ ПЕРВАЯ', '', '     I', '']
    lines += wrapped(PARAS_RU, 70, '     ')
    lines += ['', '     II', '']
    lines += wrapped(PARAS_RU_2, 70, '     ')
    lines += ['     Слово на переносе: какой-', 'нибудь пример в конце.']
    write('cp1251_librus.txt', '\r\n'.join(lines).encode('cp1251'))

    # KOI8-R, lines cut at ~64 chars, blank lines between paragraphs,
    # chapter titles in capitals. KOI8-R has no em dash: old files use `-`.
    lines = ['ТИХОЕ УТРО', '']
    for p in PARAS_RU:
        lines += textwrap.wrap(p, width=64, break_on_hyphens=False) + ['']
    lines += ['ДОЖДЬ', '']
    for p in PARAS_RU_2:
        lines += textwrap.wrap(p, width=64, break_on_hyphens=False) + ['']
    write('koi8r_blank.txt',
          '\n'.join(lines).replace('—', '-').encode('koi8_r'))

    # UTF-16 LE with BOM.
    write('utf16le_bom.txt', '﻿'.encode('utf-16-le') +
          '\n'.join(PARAS_RU[:2]).encode('utf-16-le'))


if __name__ == '__main__':
    main()
