"""Builds the small EPUB books in test/fixtures/epub/ (EPUB 2 and 3, broken
markup, encodings, DRM, empty spine). Run from the project root:
python tool/fixtures/make_epub_fixtures.py
The texts are written for the tests, no copyright."""

import pathlib
import zipfile

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


if __name__ == '__main__':
    epub3()
    epub2()
    cp1251()
    drm()
    empty_spine()
