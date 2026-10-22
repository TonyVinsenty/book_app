"""Builds the small EPUB books in test/fixtures/epub/ (EPUB 2 and 3, broken
markup, encodings, DRM, empty spine, chapters by the contents). Run from the project root:
python tool/fixtures/make_epub_fixtures.py
The texts are written for the tests, no copyright."""

import pathlib
import zipfile

import fixture_images as img

OUT = pathlib.Path('test/fixtures/epub')

CONTAINER = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="{path}" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''

XHTML_HEAD = '''<?xml version="1.0" encoding="{enc}"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>{title}</title><style>p {{ text-indent: 1em; }}</style></head>
<body>
'''


def xhtml(body, title='x', enc='utf-8'):
    return XHTML_HEAD.format(enc=enc, title=title) + body + '\n</body>\n</html>\n'


def write(name, entries, mimetype_first=True):
    """entries: list of (path, str | bytes); mimetype is added here."""
    OUT.mkdir(parents=True, exist_ok=True)
    mimetype = ('mimetype', 'application/epub+zip')
    items = [mimetype] + entries if mimetype_first else entries + [mimetype]
    with zipfile.ZipFile(OUT / name, 'w') as z:
        for path, data in items:
            if isinstance(data, str):
                data = data.encode('utf-8')
            method = zipfile.ZIP_STORED if path == 'mimetype' else zipfile.ZIP_DEFLATED
            z.writestr(zipfile.ZipInfo(path), data, compress_type=method)


# --- EPUB 3, Russian: metadata with refines, nav, notes, poems, fonts ---

EPUB3_OPF = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:12345678-1234-1234-1234-123456789abc</dc:identifier>
    <dc:title id="sub">Повесть в трёх главах</dc:title>
    <meta refines="#sub" property="title-type">subtitle</meta>
    <dc:title id="main">Утро   над рекой</dc:title>
    <meta refines="#main" property="title-type">main</meta>
    <dc:creator id="a1">Анна Тестова</dc:creator>
    <meta refines="#a1" property="role" scheme="marc:relators">aut</meta>
    <dc:creator id="e1">Иван Редакторов</dc:creator>
    <meta refines="#e1" property="role" scheme="marc:relators">edt</meta>
    <dc:creator>Пётр Соавтор</dc:creator>
    <dc:language>RU</dc:language>
    <dc:description>&lt;p&gt;Короткая повесть о &lt;i&gt;тихом&lt;/i&gt; утре.&lt;/p&gt;&lt;p&gt;Вторая&amp;nbsp;строка.&lt;/p&gt;</dc:description>
    <meta property="belongs-to-collection" id="c1">Тестовые книги</meta>
    <meta refines="#c1" property="collection-type">series</meta>
    <meta refines="#c1" property="group-position">2</meta>
    <meta property="dcterms:modified">2026-10-19T00:00:00Z</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="cover" href="text/cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover-img" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>
    <item id="ch1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="notes" href="text/notes.xhtml" media-type="application/xhtml+xml"/>
    <item id="css" href="style.css" media-type="text/css"/>
    <item id="font" href="fonts/serif.otf" media-type="font/otf"/>
  </manifest>
  <spine>
    <itemref idref="cover" linear="no"/>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
    <itemref idref="notes"/>
    <itemref idref="css"/>
  </spine>
</package>'''

EPUB3_NAV = xhtml('''<nav epub:type="toc"><ol>
  <li><a href="text/ch1.xhtml">Глава 1. Туман</a></li>
  <li><a href="text/ch2.xhtml">Глава 2. Гости</a></li>
</ol></nav>''')

EPUB3_COVER = xhtml('''<div class="cover"><svg xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 600 800">
  <title>Обложка</title><image xlink:href="../images/cover.jpg"/></svg></div>''')

EPUB3_CH1 = xhtml('''<section epub:type="chapter">
<h1>Глава 1<br/>Туман</h1>
<div class="epigraph">
  <div class="poem"><p>Над рекой туман клубится,<br/>Солнце прячется в лесу.</p></div>
  <p class="text-author">Народное</p>
</div>
<p>Утро было <em>тихим</em>, и&nbsp;над рекой ещё стоял
   туман.<a epub:type="noteref" href="notes.xhtml#n1">1</a> Анна вышла на
   <strong>крыльцо</strong>.</p>
<p>&nbsp;&nbsp;&nbsp;— Ты опять встала раньше всех?<a href="notes.xhtml#n2"><sup>[2]</sup></a> — спросил отец.</p>
<p>&nbsp;</p>
<p><img src="../images/pic.png" alt="Картинка"/></p>
<hr/>
<blockquote><p>Тишина — лучший <b>собеседник</b>.</p></blockquote>
<div class="stanza">
  <p class="v">Белеет парус одинокий</p>
  <p class="v">В тумане моря голубом.</p>
</div>
<p class="subtitle">* * *</p>
<p>Конец главы со <a href="https://example.com/">ссылкой</a> и сноской<a href="#n3">3</a>.</p>
<aside epub:type="footnote" id="n3"><p>Сноска внутри главы.</p></aside>
</section>''', title='Глава 1')

EPUB3_CH2 = xhtml('''<H2 class="chapter">Глава 2<br/>Гости</H2>
<P>Гости приехали к&nbsp;обеду &mdash; шумные &laquo;городские&raquo;.
<P>Второй абзац без закрывающего тега.
<div>Текст прямо в div <p>и абзац внутри</p> и хвост.</div>
<table><tr><td>Ячейка 1</td><td>Ячейка 2</td></tr><tr><th>Итог</th><td>3</td></tr></table>
<ul><li>Первый пункт</li><li>Второй <i>пункт</i></li></ul>
<pre>строка один
  строка два</pre>
<p>Ма&shy;ма мы&shy;ла ра&shy;му.</p>
<script>var notText = 1;</script>
''', title='Глава 2')

EPUB3_NOTES = xhtml('''<section epub:type="footnotes">
<aside epub:type="footnote" id="n1"><p>Первая сноска.</p></aside>
<aside epub:type="footnote" id="n2"><p>Вторая сноска.</p></aside>
</section>''')

EPUB3_ENCRYPTION = '''<?xml version="1.0" encoding="UTF-8"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container"
  xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
  <enc:EncryptedData>
    <enc:EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
    <enc:CipherData><enc:CipherReference URI="OEBPS/fonts/serif.otf"/></enc:CipherData>
  </enc:EncryptedData>
</encryption>'''


def epub3():
    write('epub3_ru.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='OEBPS/content.opf')),
        ('META-INF/encryption.xml', EPUB3_ENCRYPTION),
        ('OEBPS/content.opf', EPUB3_OPF),
        ('OEBPS/nav.xhtml', EPUB3_NAV),
        ('OEBPS/text/cover.xhtml', EPUB3_COVER),
        ('OEBPS/text/ch1.xhtml', EPUB3_CH1),
        ('OEBPS/text/ch2.xhtml', EPUB3_CH2),
        ('OEBPS/text/notes.xhtml', EPUB3_NOTES),
        ('OEBPS/style.css', 'p { margin: 0; }'),
        ('OEBPS/fonts/serif.otf', bytes(range(256)) * 4),
        ('OEBPS/images/cover.jpg', b'\xff\xd8\xff\xe0' + bytes(100)),
    ])


# --- EPUB 2, Gutenberg-like: mimetype last, NCX, odd links, broken markup ---

EPUB2_OPF = '''<?xml version='1.0' encoding='utf-8'?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>The Quiet Morning</dc:title>
    <dc:creator opf:role="aut" opf:file-as="Tester, Ann">Ann Tester</dc:creator>
    <dc:creator opf:role="ill">Bob Painter</dc:creator>
    <dc:language>en</dc:language>
    <dc:identifier id="id">http://www.gutenberg.org/99999</dc:identifier>
    <meta name="calibre:series" content="Test Books"/>
    <meta name="calibre:series_index" content="3.0"/>
    <meta name="cover" content="cover-img"/>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="title" href="text/title%20page.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch1" href="Text/Chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch1b" href="text/chapter1b.html" media-type="text/html"/>
    <item id="lost" href="text/lost.xhtml" media-type="application/xhtml+xml"/>
    <item id="broken" href="./text/../text/broken.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover-img" href="cover.png" media-type="image/png"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="title"/>
    <itemref idref="ch1"/>
    <itemref idref="ch1b"/>
    <itemref idref="ch1"/>
    <itemref idref="missing-id"/>
    <itemref idref="lost"/>
    <itemref idref="broken"/>
    <itemref idref="cover-img"/>
  </spine>
</package>'''

EPUB2_NCX = '''<?xml version='1.0' encoding='utf-8'?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap><navPoint id="p1" playOrder="1"><navLabel><text>CHAPTER I.</text></navLabel>
  <content src="text/chapter1.xhtml"/></navPoint></navMap>
</ncx>'''

EPUB2_TITLE = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Title</title></head>
<body><div class="titlepage">
<p class="center">THE QUIET MORNING</p>
<p class="center">by Ann Tester</p>
</div></body></html>'''

EPUB2_CH1 = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>I</title></head>
<body>
<h2><a id="chap01"></a>CHAPTER I.</h2>
<p>It was a quiet morning&mdash;the river&rsquo;s fog had not yet lifted.
Ann went out onto the porch.</p>
<p>&ldquo;Up before everyone again?&rdquo; asked her father.<a id="page_2"></a></p>
<div class="poem"><div class="stanza">
<span class="i0">The fog lies over the river,<br/></span>
<span class="i2">The sun is hiding in the wood.<br/></span>
</div></div>
</body></html>'''

# HTML rather than XHTML: no declaration, unclosed tags, `<br>`.
EPUB2_CH1B = '''<html><head><title>I (continued)</title></head>
<body>
<p>The chapter goes on in a second file, cut by size.<br>Next line.
<p>Another paragraph &copy; 1900 &amp; more.
</body></html>'''

EPUB2_BROKEN = '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Broken</title></head>
<body>
<h2>CHAPTER II.</h2>
<p class=plain>Unquoted attribute, still a paragraph.</p>
<p>Fish & chips, and 1 < 2 is true.</p>
<p>Unknown &foo; entity stays.</p>
<p>The last <em>words</em> of the book.</p>
'''


def epub2():
    write('epub2_gutenberg.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='OEBPS/content.opf')),
        ('OEBPS/content.opf', EPUB2_OPF),
        ('OEBPS/toc.ncx', EPUB2_NCX),
        ('OEBPS/text/title page.xhtml', EPUB2_TITLE),
        ('OEBPS/text/chapter1.xhtml', EPUB2_CH1),
        ('OEBPS/text/chapter1b.html', EPUB2_CH1B),
        ('OEBPS/text/broken.xhtml', EPUB2_BROKEN),
        ('OEBPS/cover.png', b'\x89PNG\r\n\x1a\n' + bytes(50)),
    ], mimetype_first=False)


# --- Windows-1251 text with the encoding only in the declaration ---

def cp1251():
    opf = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:language>ru</dc:language></metadata>
  <manifest><item id="t" href="text.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="t"/></spine>
</package>'''
    body = xhtml('<h1>Старая кодировка</h1>\n<p>Текст в Windows-1251: ёжик, «ёлка», щука.</p>',
                 enc='windows-1251')
    write('cp1251.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='content.opf')),
        ('content.opf', opf),
        ('text.xhtml', body.encode('cp1251')),
    ])


# --- Adobe DRM: rights.xml and the text listed in encryption.xml ---

def drm():
    opf = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Locked</dc:title></metadata>
  <manifest><item id="t" href="text.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="t"/></spine>
</package>'''
    encryption = '''<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container"
  xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
  <enc:EncryptedData>
    <enc:EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/>
    <enc:CipherData><enc:CipherReference URI="OEBPS/text.xhtml"/></enc:CipherData>
  </enc:EncryptedData>
</encryption>'''
    write('drm.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='OEBPS/content.opf')),
        ('META-INF/rights.xml', '<?xml version="1.0"?><adept:rights xmlns:adept="http://ns.adobe.com/adept"/>'),
        ('META-INF/encryption.xml', encryption),
        ('OEBPS/content.opf', opf),
        ('OEBPS/text.xhtml', bytes((i * 151 + 7) % 256 for i in range(3000))),
    ])


def empty_spine():
    opf = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Empty</dc:title></metadata>
  <manifest><item id="t" href="text.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine/>
</package>'''
    write('empty_spine.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='content.opf')),
        ('content.opf', opf),
        ('text.xhtml', xhtml('<p>Nobody reads this.</p>')),
    ])


# --- Chapters from the contents (step 7.3) ---

def one_file():
    """The whole book in one file, chapters by anchors (Wikisource-like:
    `I` as a paragraph), a nested nav with a label without a link, a
    missing anchor, an appendix file and a notes file without a link."""
    opf = """<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Одна книга</dc:title></metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="book" href="book.xhtml" media-type="application/xhtml+xml"/>
    <item id="app" href="appendix.xhtml" media-type="application/xhtml+xml"/>
    <item id="more" href="more.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="book"/><itemref idref="app"/><itemref idref="more"/></spine>
</package>"""
    nav = xhtml("""<nav epub:type="landmarks" hidden=""><ol>
  <li><a href="book.xhtml#c2">Не оглавление</a></li></ol></nav>
<nav epub:type="toc"><h1>Содержание</h1><ol>
  <li><a href="book.xhtml#p1">Часть первая</a><ol>
    <li><a href="book.xhtml#c1">I</a></li>
    <li><a href="book.xhtml#c2">II</a></li>
    <li><a href="book.xhtml#nowhere">III</a></li>
  </ol></li>
  <li><a href="book.xhtml#p2">Часть
     вторая</a><ol><li><a href="book.xhtml#c4">IV</a></li></ol></li>
  <li><span>Приложения</span><ol>
    <li><a href="appendix.xhtml">Письма</a></li>
    <li><a href="https://example.com/">Сайт</a></li>
  </ol></li>
</ol></nav>""")
    book = xhtml("""<h1>Одна книга</h1>
<p>Предисловие без ссылки в оглавлении.</p>
<h2 id="p1">Часть первая</h2>
<p class="center" id="c1">I</p>
<p>Первая глава, один абзац.</p>
<p>Второй абзац первой главы.</p>
<hr/>
<div id="c2"><p class="center">II</p>
<p>Вторая глава. Здесь <span id="nowhere-else">якорь</span> не тот.</p>
<p>III</p>
<p>Третья глава без своего якоря остаётся во второй.</p></div>
<h2><a id="p2"></a>Часть вторая</h2>
<p>Вступление ко второй части.<a id="c4"></a></p>
<p>IV</p>
<p>Четвёртая глава до конца файла.</p>""")
    appendix = xhtml('<h3>Письма</h3>\n<p>Письмо первое.</p>')
    more = xhtml('<p>Продолжение писем, без ссылки и без заголовка.</p>')
    write('one_file.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='content.opf')),
        ('content.opf', opf),
        ('nav.xhtml', nav),
        ('book.xhtml', book),
        ('appendix.xhtml', appendix),
        ('more.xhtml', more),
    ])


def calibre_split():
    """EPUB 2 cut by size (Calibre): a nested NCX, a file going on the
    chapter before, a file starting with a heading of its own, links to
    a picture and to a file start by its anchor."""
    files = ['index_split_000.html', 'index_split_001.html',
             'index_split_002.html', 'index_split_003.html']
    opf = """<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Split Book</dc:title></metadata>
  <manifest>
    <item id="toc" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="cover" href="cover.jpeg" media-type="image/jpeg"/>
""" + ''.join(f'    <item id="s{i}" href="{f}" media-type="application/xhtml+xml"/>\n'
              for i, f in enumerate(files)) + """  </manifest>
  <spine toc="toc">""" + ''.join(f'<itemref idref="s{i}"/>' for i in range(len(files))) + """</spine>
</package>"""
    ncx = """<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><navMap>
  <navPoint id="n0"><navLabel><text>Cover</text></navLabel><content src="cover.jpeg"/></navPoint>
  <navPoint id="n1"><navLabel><text>Part One</text></navLabel><content src="index_split_000.html#part1"/>
    <navPoint id="n2"><navLabel><text>Chapter 1</text></navLabel><content src="index_split_000.html#ch1"/></navPoint>
    <navPoint id="n3"><navLabel><text>Chapter 2</text></navLabel><content src="index_split_002.html#ch2"/>
      <navPoint id="n4"><navLabel><text>A Letter</text></navLabel><content src="index_split_002.html#letter"/></navPoint>
    </navPoint>
  </navPoint>
</navMap></ncx>"""
    bodies = [
        """<p class="title">SPLIT BOOK</p>
<h1 id="part1">Part One</h1>
<h2 id="ch1">Chapter 1</h2>
<p>The first chapter begins here.</p>""",
        """<p>It goes on in the next file, cut by size.</p>""",
        """<h2 id="ch2">Chapter 2</h2>
<p>The second chapter.</p>
<p id="letter">Dear friend, this is a letter.</p>""",
        """<h3>Afterword</h3>
<p>Not in the contents, but a heading of its own.</p>""",
    ]
    write('calibre_split.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='content.opf')),
        ('content.opf', opf),
        ('toc.ncx', ncx),
        ('cover.jpeg', b'\xff\xd8\xff\xe0' + bytes(20)),
    ] + [(f, xhtml(b)) for f, b in zip(files, bodies)])


# --- Stage 12: images and footnotes (no snapshots until 12.5) ---

SVG_NS = ('xmlns="http://www.w3.org/2000/svg" '
          'xmlns:xlink="http://www.w3.org/1999/xlink"')


def simple_opf(title, manifest, spine, version='3.0', extra=''):
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="{version}" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:00000000-0000-0000-0000-000000000012</dc:identifier>
    <dc:title>{title}</dc:title><dc:language>ru</dc:language>{extra}
  </metadata>
  <manifest>
{manifest}
  </manifest>
  <spine>{spine}</spine>
</package>'''


def item(id_, href, mime='application/xhtml+xml', props=''):
    p = f' properties="{props}"' if props else ''
    return f'    <item id="{id_}" href="{href}" media-type="{mime}"{p}/>'


def epub_images():
    """Pictures in every shape: a cover page (svg wrapper), a page with
    only a picture, <img> inside a paragraph (text before and after), a
    lone <img>, an svg wrapper in a chapter, a pure svg drawing, a broken
    and a missing picture, huge sizes, the same picture twice, and a
    picture-only page at the very end of the book."""
    manifest = '\n'.join([
        item('nav', 'nav.xhtml', props='nav'),
        item('cover', 'cover.xhtml'),
        item('cover-img', 'img/cover.jpg', 'image/jpeg', 'cover-image'),
        item('plate', 'plate.xhtml'),
        item('ch1', 'ch1.xhtml'),
        item('ch2', 'ch2.xhtml'),
        item('endpage', 'endpage.xhtml'),
        item('i1', 'img/p1.png', 'image/png'),
        item('i2', 'img/p2.gif', 'image/gif'),
        item('i3', 'img/p3.jpg', 'image/jpeg'),
        item('ibroken', 'img/broken.png', 'image/png'),
        item('ihuge', 'img/huge.png', 'image/png'),
        item('ihugej', 'img/huge.jpg', 'image/jpeg'),
        item('ispacer', 'img/spacer.png', 'image/png'),
    ])
    spine = ''.join(f'<itemref idref="{i}"/>'
                    for i in ['cover', 'plate', 'ch1', 'ch2', 'endpage'])
    nav = xhtml('''<nav epub:type="toc"><ol>
  <li><a href="ch1.xhtml">Глава 1</a></li>
  <li><a href="ch2.xhtml">Глава 2</a></li></ol></nav>''')
    cover = xhtml(f'''<div class="cover"><svg {SVG_NS} version="1.1"
  viewBox="0 0 120 160" preserveAspectRatio="xMidYMid meet">
  <image width="120" height="160" xlink:href="img/cover.jpg"/></svg></div>''')
    plate = xhtml('<div><img src="img/p1.png" alt="Фронтиспис"/></div>')
    ch1 = xhtml('''<h1>Глава 1</h1>
<p>Текст до картинки <img src="img/p2.gif" alt="значок"/> и после неё в том же
   абзаце, чтобы абзац пришлось разрезать на две части.</p>
<p><img src="img/p3.jpg" alt="Одинокая"/></p>
<p>Абзац между картинками.</p>
<p>Картинка в начале абзаца: <img src="img/p1.png"/></p>
<p><img src="img/p1.png"/> и в начале, повторная.</p>
<div class="fig"><img src="img/p3.jpg" alt=""/><p class="cap">Подпись под рисунком.</p></div>
<p>Спейсер <img src="img/spacer.png" alt=""/> внутри слова не картинка-страница.</p>''',
                title='Глава 1')
    ch2 = xhtml(f'''<h1>Глава 2</h1>
<p>Обёртка svg в середине главы:</p>
<div><svg {SVG_NS} viewBox="0 0 200 120"><image width="200" height="120"
  xlink:href="img/p1.png"/></svg></div>
<p>Чистый svg-рисунок (его показать нельзя, пропускается):</p>
<svg {SVG_NS} viewBox="0 0 100 100" width="100" height="100">
  <rect x="10" y="10" width="80" height="80" fill="#c33"/>
  <circle cx="50" cy="50" r="30" fill="#fff"/><text x="30" y="55">SVG</text></svg>
<p>Битая и пропавшая картинки:</p>
<p><img src="img/broken.png" alt="битая"/></p>
<p><img src="img/nothere.png" alt="нет файла"/></p>
<p>Огромные размеры:</p>
<p><img src="img/huge.png" alt="20000 на 20000"/></p>
<p><img src="img/huge.jpg" alt="12000 на 9000"/></p>
<p>Внешняя картинка: <img src="https://example.com/x.png" alt="внешняя"/> и
   картинка без src: <img alt="пусто"/> и data-ссылка:
   <img src="data:image/png;base64,AAAA" alt="data"/>.</p>
<p>Конец главы 2.</p>''', title='Глава 2')
    endpage = xhtml('<p><img src="img/p3.jpg" alt="Послесловие-картинка"/></p>')
    write('epub_images.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='OEBPS/content.opf')),
        ('OEBPS/content.opf', simple_opf('Книга с картинками', manifest, spine)),
        ('OEBPS/nav.xhtml', nav),
        ('OEBPS/cover.xhtml', cover),
        ('OEBPS/plate.xhtml', plate),
        ('OEBPS/ch1.xhtml', ch1),
        ('OEBPS/ch2.xhtml', ch2),
        ('OEBPS/endpage.xhtml', endpage),
        ('OEBPS/img/cover.jpg', img.jpeg(120, 160)),
        ('OEBPS/img/p1.png', img.png(200, 120, 1)),
        ('OEBPS/img/p2.gif', img.gif(40, 30)),
        ('OEBPS/img/p3.jpg', img.jpeg(160, 100)),
        ('OEBPS/img/broken.png', b'\x89PNG\r\n\x1a\n' + bytes(range(40))),
        ('OEBPS/img/huge.png', img.png_header_only(20000, 20000)),
        ('OEBPS/img/huge.jpg', img.jpeg_header_only(12000, 9000)),
        ('OEBPS/img/spacer.png', img.png(1, 1)),
    ])


def epub_images_only():
    """A book made almost only of pictures (a comic or a photo album):
    every spine file has a picture and one has a short caption; one chapter
    must not be created for a file without words."""
    files = ['cover', 'a1', 'a2', 'a3']
    manifest = '\n'.join(
        [item(f, f'{f}.xhtml') for f in files]
        + [item('p1', 'p1.png', 'image/png'), item('p2', 'p2.jpg', 'image/jpeg')])
    spine = ''.join(f'<itemref idref="{f}"/>' for f in files)
    write('epub_images_only.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='content.opf')),
        ('content.opf', simple_opf('Только картинки', manifest, spine,
                                   version='2.0')),
        ('cover.xhtml', xhtml('<img src="p2.jpg" alt=""/>')),
        ('a1.xhtml', xhtml('<p><img src="p1.png"/></p>')),
        ('a2.xhtml', xhtml('<p><img src="p2.jpg"/></p><p>Подпись.</p>')),
        ('a3.xhtml', xhtml('<p><img src="p1.png"/></p>')),
        ('p1.png', img.png(160, 100, 2)),
        ('p2.jpg', img.jpeg(120, 160)),
    ])


def epub_notes_aside():
    """Notes in the chapter itself: <aside epub:type=footnote|endnote>,
    doc-noteref role, a back-link, a nested note, a link to nowhere."""
    manifest = '\n'.join([item('ch1', 'ch1.xhtml'), item('ch2', 'ch2.xhtml')])
    ch1 = xhtml('''<h1>Сноски в главе</h1>
<p>Первая сноска<a epub:type="noteref" href="#fn1" id="r1">1</a> рядом со
   словом, вторая<a role="doc-noteref" href="#fn2" id="r2"><sup>2</sup></a>,
   третья через звёздочку<a epub:type="noteref" href="#fn3" id="r3">*</a>.</p>
<p>Метка без цели<a epub:type="noteref" href="#nope">[7]</a> и метка на
   другой файл без файла<a epub:type="noteref" href="gone.xhtml#x">8</a>.</p>
<aside epub:type="footnote" id="fn1"><p>Текст первой сноски.
  <a href="#r1">↩</a></p></aside>
<aside epub:type="footnote" id="fn2"><p>Вторая сноска из двух абзацев.</p>
  <p>Второй абзац, и вложенная сноска<a epub:type="noteref" href="#fn4">4</a>.
  <a href="#r2" class="backlink">↩︎</a></p></aside>
<aside epub:type="endnote" id="fn3"><p>3) Третья, в стиле endnote.</p></aside>
<aside epub:type="footnote" id="fn4"><p>Вложенная, она ссылается обратно на
  вторую<a epub:type="noteref" href="#fn2">2</a>.</p></aside>
<p>Текст после сносок продолжается.</p>''', title='Глава 1')
    ch2 = xhtml('''<h1>Вторая глава</h1>
<p>Сноска в другой главе, но с целью в первой<a epub:type="noteref"
   href="ch1.xhtml#fn1">1</a>.</p>
<p>Конец.</p>''', title='Глава 2')
    write('epub_notes_aside.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='content.opf')),
        ('content.opf', simple_opf('Сноски aside', manifest,
                                   '<itemref idref="ch1"/><itemref idref="ch2"/>')),
        ('ch1.xhtml', ch1),
        ('ch2.xhtml', ch2),
    ])


def epub_notes_files():
    """Notes in separate files, the Gutenberg/Calibre way: one notes file
    in the spine, one only in the manifest; targets are <p>, <li>, <dd>,
    <div>; back-links as a symbol and as '1)'; a nested note; a link to a
    file that is not there."""
    manifest = '\n'.join([
        item('ch1', 'text/ch1.xhtml'),
        item('notes', 'text/notes.xhtml'),
        item('hidden', 'text/hidden_notes.xhtml'),
    ])
    spine = ('<itemref idref="ch1"/><itemref idref="notes"/>')
    ch1 = xhtml('''<h1>Сноски в файлах</h1>
<p id="t1">Сноска в файле из spine<a href="notes.xhtml#n1" id="b1"><sup>1</sup></a>
   и вторая<a href="notes.xhtml#n2" id="b2">[2]</a>.</p>
<p>Сноска в файле вне spine<a href="hidden_notes.xhtml#h1">3</a>, в
   стиле dd<a href="hidden_notes.xhtml#h2">4</a>, в div<a
   href="hidden_notes.xhtml#h3">5</a> и в li<a href="hidden_notes.xhtml#h4">6</a>.</p>
<p>Вложенная цепочка<a href="notes.xhtml#n3">7</a> и цель без элемента<a
   href="notes.xhtml#missing">8</a> и файл не найден<a
   href="text/zzz.xhtml#a">9</a>.</p>
<p>Обычная ссылка <a href="notes.xhtml">на файл</a> и на
   <a href="https://example.com/">сайт</a> — не сноски.</p>''', title='Глава')
    notes = xhtml('''<h2>Примечания</h2>
<p id="n1"><a href="ch1.xhtml#b1">1)</a> Первое примечание в spine.</p>
<p id="n2">Второе примечание. <a href="ch1.xhtml#b2">↩</a></p>
<p id="n3"><a href="ch1.xhtml#t1">[7]</a> Примечание со ссылкой на
   другое<a href="hidden_notes.xhtml#h1">3</a>.</p>''', title='Примечания')
    hidden = xhtml('''<h2>Скрытые примечания</h2>
<p id="h1">Скрытое примечание, один абзац. <a href="ch1.xhtml">↑</a></p>
<dl><dt>4</dt><dd id="h2">Определение-примечание.</dd></dl>
<div id="h3"><p>Примечание в div, абзац первый.</p><p>Абзац второй.</p></div>
<ol><li id="h4">Примечание в li. <a href="ch1.xhtml">↩︎</a></li></ol>''',
                   title='Скрытые')
    write('epub_notes_files.epub', [
        ('META-INF/container.xml', CONTAINER.format(path='content.opf')),
        ('content.opf', simple_opf('Сноски в файлах', manifest, spine)),
        ('text/ch1.xhtml', ch1),
        ('text/notes.xhtml', notes),
        ('text/hidden_notes.xhtml', hidden),
    ])


if __name__ == '__main__':
    epub3()
    epub2()
    cp1251()
    drm()
    empty_spine()
    one_file()
    calibre_split()
    epub_images()
    epub_images_only()
    epub_notes_aside()
    epub_notes_files()
