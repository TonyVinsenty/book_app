import 'package:book_app/layout/hyphenation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Hyphenation hyphenation;

  setUpAll(() async => hyphenation = await Hyphenation.load());

  String hyphenate(String text) {
    final breaks = hyphenation.breaksOf(text);
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (breaks.contains(i)) out.write('-');
      out.write(text[i]);
    }
    return out.toString();
  }

  test('breaks Russian words by syllables', () {
    expect(
      hyphenate('Андрей Болконский подъезжал к Лысым Горам'),
      'Ан-дрей Бол-кон-ский подъ-ез-жал к Лы-сым Горам',
    );
    expect(
      hyphenate('сельскохозяйственный год'),
      'сель-ско-хо-зяй-ствен-ный год',
    );
  });

  test('words with «ё» use the «ё» patterns, the text is unchanged', () {
    expect(hyphenate('зелёного цвета'), 'зе-лё-но-го цвета');
    expect(hyphenate('полёт ещё'), 'по-лёт ещё');
    expect(hyphenate('зелёного').replaceAll('-', ''), 'зелёного');
  });

  test('breaks English words, with the exceptions list', () {
    expect(hyphenate('hyphenation computer.'), 'hy-phen-ation computer.');
    expect(hyphenate('computer table'), 'com-puter table');
    expect(hyphenate('present table now'), 'present ta-ble now');
  });

  test('capitals, short words and marked words stay whole', () {
    expect(hyphenate('СССР НАТО ещё он'), 'СССР НАТО ещё он');
    expect(hyphenate('Ударе́ние'), 'Ударе́ние');
  });

  test('parts of a hyphenated word break on their own', () {
    expect(hyphenate('какой-нибудь день'), 'ка-кой-ни-будь день');
  });

  test('the last word of a text stays whole', () {
    expect(hyphenate('стояла рядом.'), 'сто-я-ла рядом.');
    expect(hyphenate('переносы'), 'переносы');
  });
}
