"""Builds the small FB2 books in test/fixtures/fb2/ (encodings, nesting,
poems, notes, broken files). Run from the project root:
python tool/fixtures/make_fb2_fixtures.py
The texts are written for the tests, no copyright."""

import base64
import pathlib
import zipfile

import fixture_images as img

OUT = pathlib.Path('test/fixtures/fb2')
ZIP_OUT = pathlib.Path('test/fixtures/zip')

HEAD = ('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" '
        'xmlns:l="http://www.w3.org/1999/xlink">')

DESCRIPTION = '''<description>
  <title-info>
    <genre>prose_classic</genre>
    <author>
      <first-name>Анна</first-name>
      <middle-name>Петровна</middle-name>
      <last-name>Тестова</last-name>
    </author>
    <author><nickname>Аноним</nickname></author>
    <book-title>Утро  над
      рекой</book-title>
    <annotation>
      <p>Короткая повесть о <emphasis>тихом</emphasis> утре.</p>
      <p>Вторая строка аннотации.</p>
    </annotation>
    <coverpage><image l:href="#cover.jpg"/></coverpage>
    <lang>RU</lang>
    <sequence name="Тестовые книги" number="2"/>
  </title-info>
  <src-title-info>
    <book-title>Не это название</book-title>
    <author><last-name>Не этот автор</last-name></author>
  </src-title-info>
  <document-info><author><nickname>верстальщик</nickname></author></document-info>
</description>'''

BODY = '''<body>
  <title><p>Анна Тестова</p><p>Утро над рекой</p></title>
  <epigraph>
    <poem>
      <stanza><v>Над рекой туман клубится,</v><v>Солнце прячется в лесу.</v></stanza>
    </poem>
    <text-author>Народное</text-author>
  </epigraph>
  <section>
    <title><p>Часть первая</p></title>
    <section>
      <title><p>Глава 1</p><p>Туман</p></title>
      <p>Утро было <emphasis>тихим</emphasis>, и над рекой ещё стоял
         туман.<a l:href="#n1" type="note">[1]</a> Анна вышла на
         <strong>крыльцо</strong>.</p>
      <p>— Ты опять встала раньше всех? — спросил отец.</p>
      <empty-line/>
      <image l:href="#pic1.png"/>
      <subtitle>* * *</subtitle>
      <p>Слова <strong>жирные и <emphasis>курсивные</emphasis></strong> рядом.</p>
      <cite>
        <p>Кто рано встаёт, тому Бог подаёт.</p>
        <text-author>Пословица</text-author>
      </cite>
    </section>
    <section>
      <title><p>Глава 2.</p><p>Гости</p></title>
      <poem>
        <title><p>Песня</p></title>
        <stanza>
          <v>Едут гости по дороге,</v>
          <v>Пыль <emphasis>клубится</emphasis> до небес.</v>
        </stanza>
        <stanza>
          <v>Ждёт их Анна на пороге,</v>
          <v>Смотрит в поле, смотрит в лес.</v>
        </stanza>
        <text-author>Анна</text-author>
      </poem>
      <p>К вечеру приехал доктор Петров.</p>
    </section>
  </section>
  <section>
    <title><p>Часть вторая</p></title>
    <epigraph><p>Ночью пошёл дождь.</p></epigraph>
    <section>
      <title><p>Глава 3</p></title>
      <p>Дождь стучал по крыше ровно и спокойно.</p>
    </section>
  </section>
  <section>
    <p>Раздел без заголовка.</p>
  </section>
</body>
<body name="notes">
  <section id="n1"><title><p>1</p></title><p>Сноска о тумане.</p></section>
</body>'''


def binary(name: str) -> str:
    data = base64.b64encode(bytes(range(256)) * 4).decode('ascii')
    return f'<binary id="{name}" content-type="image/png">{data}</binary>'


def write(name: str, data: bytes) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_bytes(data)


def nested_utf8() -> None:
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n' + HEAD + '\n'
           + DESCRIPTION + '\n' + BODY + '\n' + binary('cover.jpg')
           + binary('pic1.png') + '\n</FictionBook>\n')
    write('utf8_nested.fb2', xml.encode('utf-8'))


def cp1251_entities() -> None:
    # HTML entities, a soft hyphen, a table, CRLF; the declaration is in
    # single quotes.
    xml = ("<?xml version='1.0' encoding='windows-1251'?>\r\n" + HEAD + '\r\n'
           '<description><title-info><author><last-name>Иванов</last-name>'
           '</author><book-title>Таблицы&nbsp;и&nbsp;знаки</book-title>'
           '<lang>ru</lang></title-info></description>\r\n'
           '<body><section><title><p>Глава&#160;первая</p></title>\r\n'
           '<p>&laquo;Сло­во&raquo; &mdash; это т.&nbsp;е. пример'
           ' &amp; проверка.</p>\r\n'
           '<table><tr><th>Год</th><th>Событие</th></tr>'
           '<tr><td>1812</td><td>Война</td></tr></table>\r\n'
           '<p><![CDATA[Текст в CDATA <без> тегов.]]></p>\r\n'
           '</section></body></FictionBook>\r\n')
    write('cp1251_entities.fb2', xml.encode('cp1251'))


def broken_tail() -> None:
    # No description, a namespace prefix, text right inside a section, an
    # unclosed <p>, and the file cut in the middle of a paragraph.
    xml = ('<?xml version="1.0" encoding="utf-8"?>\n'
           '<fb:FictionBook xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0">'
           '<fb:body><fb:section><fb:title><fb:p>Начало</fb:p></fb:title>\n'
           'Текст прямо в разделе, без абзаца.\n'
           '<fb:p>Абзац без конца\n'
           '<fb:p>Следующий абзац.</fb:p></fb:section>\n'
           '<fb:section><fb:title><fb:p>Обрыв</fb:p></fb:title>'
           '<fb:p>Первый целый абзац.</fb:p>'
           '<fb:p>Этот абзац оборв')
    write('broken_tail.fb2', xml.encode('utf-8'))




# --- Stage 12: images and footnotes (no snapshots until 12.4) ---

def b64(data: bytes, wrap: int = 0) -> str:
    text = base64.b64encode(data).decode('ascii')
    if wrap:
        text = '\n'.join(text[i:i + wrap] for i in range(0, len(text), wrap))
    return text


def bin_tag(name: str, mime: str, payload: str) -> str:
    return f'<binary id="{name}" content-type="{mime}">{payload}</binary>'


def fb2_doc(title: str, body: str, tail: str = '', head: str = '',
            cover: str = '') -> bytes:
    cover_xml = f'<coverpage><image l:href="{cover}"/></coverpage>' if cover else ''
    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n' + HEAD + '\n'
           '<description><title-info><genre>prose_classic</genre>'
           '<author><first-name>Анна</first-name><last-name>Тестова'
           f'</last-name></author><book-title>{title}</book-title>'
           f'{cover_xml}<lang>ru</lang></title-info></description>\n'
           + head + body + '\n' + tail + '\n</FictionBook>\n')
    return xml.encode('utf-8')


def images_basic() -> None:
    # JPEG, PNG and GIF; a binary before the body and one after; the cover
    # is the first picture; one picture used twice; a 1x1 spacer.
    before = (bin_tag('cover.jpg', 'image/jpeg', b64(img.jpeg(120, 160)))
              + bin_tag('plate1.png', 'image/png', b64(img.png(200, 120, 1),
                                                        76)))
    after = (bin_tag('vignette.gif', 'image/gif', b64(img.gif(40, 30)))
             + bin_tag('plate2.jpg', 'image/jpeg', b64(img.jpeg(160, 100)))
             + bin_tag('spacer.png', 'image/png', b64(img.png(1, 1))))
    body = """<body>
  <title><p>Книга с картинками</p></title>
  <section>
    <title><p>Глава 1</p></title>
    <p>Перед первой картинкой идёт обычный текст из нескольких слов.</p>
    <image l:href="#plate1.png"/>
    <p>После картинки текст продолжается, и ещё одна фраза для длины.</p>
    <p>Строка с виньеткой:</p>
    <image l:href="#vignette.gif"/>
    <image l:href="#spacer.png"/>
    <p>Хвост главы.</p>
  </section>
  <section>
    <title><p>Глава 2</p></title>
    <image l:href="#plate2.jpg"/>
    <p>Картинка в начале главы, а ниже она же повторена.</p>
    <image l:href="#plate1.png"/>
    <p>Конец.</p>
  </section>
</body>"""
    write('images_basic.fb2', fb2_doc('Книга с картинками', body, after,
                                      before, cover='#cover.jpg'))


def images_broken() -> None:
    # Everything that must not crash and must not leave an empty frame:
    # broken base64, a missing binary, huge sizes, not an image at all,
    # an id used by two binaries, a cover pointing nowhere.
    good = bin_tag('ok.png', 'image/png', b64(img.png(80, 60, 2)))
    broken = bin_tag('broken.png', 'image/png', '@@@@ not base64 !!!!')
    cut = bin_tag('cut.png', 'image/png', b64(img.png(80, 60))[:60])
    huge_png = bin_tag('huge.png', 'image/png',
                       b64(img.png_header_only(20000, 20000)))
    huge_jpg = bin_tag('huge.jpg', 'image/jpeg',
                       b64(img.jpeg_header_only(12000, 9000)))
    text_bin = bin_tag('text.jpg', 'image/jpeg',
                       b64('Это не картинка, а текст.'.encode('utf-8')))
    empty = bin_tag('empty.png', 'image/png', '')
    dup1 = bin_tag('dup.png', 'image/png', b64(img.png(30, 30, 0)))
    dup2 = bin_tag('dup.png', 'image/png', b64(img.png(90, 90, 1)))
    body = """<body>
  <section>
    <title><p>Глава с битыми картинками</p></title>
    <p>Текст до первой картинки.</p>
    <image l:href="#ok.png"/>
    <p>Дальше идут картинки, которые показать нельзя.</p>
    <image l:href="#broken.png"/>
    <p>Картинка с битым base64 пропущена, текст цел.</p>
    <image l:href="#cut.png"/>
    <image l:href="#missing.png"/>
    <p>Картинка без binary пропущена.</p>
    <image l:href="#huge.png"/>
    <image l:href="#huge.jpg"/>
    <p>Огромные по размеру картинки не показываются.</p>
    <image l:href="#text.jpg"/>
    <image l:href="#empty.png"/>
    <image l:href="#dup.png"/>
    <image/>
    <image l:href="not-a-local-ref"/>
    <p>Последний абзац главы.</p>
  </section>
</body>"""
    write('images_broken.fb2',
          fb2_doc('Битые картинки', body, '', good + broken + cut + huge_png
                  + huge_jpg + text_bin + empty + dup1 + dup2,
                  cover='#no-cover.jpg'))


def notes_basic() -> None:
    # Notes in body name="notes" and name="comments", all kinds of labels,
    # a note that refers to another note, a label with no target, a note
    # nobody refers to, a second link to the same note.
    body = """<body>
  <title><p>Книга со сносками</p></title>
  <section>
    <title><p>Глава 1</p></title>
    <p>Первая сноска стоит после слова<a l:href="#n1" type="note">[1]</a> и
       идёт дальше. Вторая — без скобок<a l:href="#n2" type="note">2</a>, с
       запятой сразу после метки.</p>
    <p>Звёздочка<a l:href="#n3" type="note">*</a> и пустая
       метка<a l:href="#n4" type="note"></a> тоже сноски.</p>
    <p>Комментарий<a l:href="#c1" type="note">{1}</a> лежит в другом теле.
       Метка без цели<a l:href="#nowhere" type="note">[9]</a> и ссылка без
       type<a l:href="#n1">[1]</a> на ту же сноску.</p>
    <p>Ссылка наружу <a l:href="https://example.com/">не сноска</a> и
       ссылка без адреса<a type="note">[?]</a>.</p>
  </section>
  <section>
    <title><p>Глава 2</p></title>
    <p>Сноска со вложенной<a l:href="#n5" type="note">[5]</a>.</p>
  </section>
</body>
<body name="notes">
  <title><p>Примечания</p></title>
  <section id="n1"><title><p>1</p></title><p>Первая сноска.</p></section>
  <section id="n2"><title><p>2</p></title>
    <p>Вторая сноска из двух абзацев.</p><p>Второй абзац второй сноски.</p>
  </section>
  <section id="n3"><p>Сноска без заголовка.</p></section>
  <section id="n4"><title><p>Пустая метка</p></title><p>Сноска для пустой метки.</p></section>
  <section id="n5"><title><p>5</p></title>
    <p>Сноска, которая ссылается на другую<a l:href="#n6" type="note">[6]</a>.</p>
  </section>
  <section id="n6"><title><p>6</p></title>
    <p>Вложенная сноска<a l:href="#n5" type="note">[5]</a> (и обратно на пятую).</p>
  </section>
  <section id="n7"><title><p>7</p></title><p>Сноска, на которую никто не ссылается.</p></section>
</body>
<body name="comments">
  <section id="c1"><title><p>1</p></title><p>Комментарий читателя.</p></section>
</body>"""
    write('notes_basic.fb2', fb2_doc('Книга со сносками', body))


def notes_many() -> None:
    # Hundreds of notes, like a scholarly edition: speed and the size of
    # the notes map. Every 7th note has a link into the next one.
    count = 300
    paras, notes = [], []
    for i in range(1, count + 1):
        paras.append(f'<p>Абзац номер {i} с мыслью<a l:href="#fn{i}" '
                     f'type="note">[{i}]</a> и продолжением текста.</p>')
        extra = (f' Смотри ещё<a l:href="#fn{i + 1}" type="note">'
                 f'[{i + 1}]</a>.' if i % 7 == 0 and i < count else '')
        notes.append(f'<section id="fn{i}"><title><p>{i}</p></title>'
                     f'<p>Пояснение к месту {i}.{extra}</p></section>')
    body = ('<body><section><title><p>Много сносок</p></title>'
            + '\n'.join(paras) + '</section></body>\n'
            '<body name="notes">' + '\n'.join(notes) + '</body>')
    write('notes_many.fb2', fb2_doc('Много сносок', body))


def write_zip(name: str, entries: list[tuple[str, bytes]]) -> None:
    # Fixed dates, so the archives come out the same on every run.
    ZIP_OUT.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ZIP_OUT / name, 'w', zipfile.ZIP_DEFLATED) as z:
        for entry, data in entries:
            z.writestr(zipfile.ZipInfo(entry, (2020, 1, 1, 0, 0, 0)), data,
                       zipfile.ZIP_DEFLATED)


def zips() -> None:
    # Packed FB2 the way libraries hand it out, and less tidy archives.
    book = (OUT / 'utf8_nested.fb2').read_bytes()
    pic = bytes(range(256)) * 4
    write_zip('plain.fb2.zip', [('utf8_nested.fb2', book)])
    write_zip('folder_first.zip', [('Книги/', b''),
                                   ('Книги/utf8_nested.fb2', book)])
    write_zip('fb2_not_first.zip', [('__MACOSX/._utf8_nested.fb2', b'mac'),
                                    ('cover.jpg', pic),
                                    ('utf8_nested.fb2', book)])
    write_zip('only_picture.zip', [('cover.jpg', pic)])
    full = (ZIP_OUT / 'plain.fb2.zip').read_bytes()
    (ZIP_OUT / 'broken.fb2.zip').write_bytes(full[:len(full) // 2])


if __name__ == '__main__':
    nested_utf8()
    cp1251_entities()
    broken_tail()
    images_basic()
    images_broken()
    notes_basic()
    notes_many()
    zips()
