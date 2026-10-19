"""Builds the small FB2 books in test/fixtures/fb2/ (encodings, nesting,
poems, notes, broken files). Run from the project root:
python tool/fixtures/make_fb2_fixtures.py
The texts are written for the tests, no copyright."""

import base64
import pathlib

OUT = pathlib.Path('test/fixtures/fb2')

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


if __name__ == '__main__':
    nested_utf8()
    cp1251_entities()
    broken_tail()
