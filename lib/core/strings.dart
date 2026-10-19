import 'package:flutter/widgets.dart';

/// UI strings in Arabic and English. The app follows the device language.
class S {
  const S._(this.ar);

  final bool ar;

  static S of(BuildContext context) =>
      S._(Localizations.localeOf(context).languageCode == 'ar');

  String _t(String arabic, String english) => ar ? arabic : english;

  // Home
  String get favorites => _t('المفضلة', 'Favorites');
  String get recent => _t('الأخيرة', 'Recent');
  String get openFile => _t('فتح ملف', 'Open file');
  String get newFile => _t('ملف جديد', 'New file');
  String get fileName => _t('اسم الملف', 'File name');
  String get create => _t('إنشاء', 'Create');
  String get cancel => _t('إلغاء', 'Cancel');
  String get emptyTitle => _t('افتح أول ملف Markdown', 'Open your first Markdown file');
  String get emptyBody => _t('الملفات التي تفتحها تظهر هنا لتعود إليها بسرعة.',
      'Files you open show up here so you can get back to them quickly.');
  String get today => _t('اليوم', 'Today');
  String get yesterday => _t('أمس', 'Yesterday');
  String percentRead(int p) => _t('قُرئ $p٪', '$p% read');
  String get favorite => _t('إضافة للمفضلة', 'Add to favorites');
  String get unfavorite => _t('إزالة من المفضلة', 'Remove from favorites');
  String get remove => _t('حذف', 'Remove');
  String get removeTitle => _t('حذف الملف من التطبيق؟', 'Remove from RelaxMD?');
  String get removeBody => _t(
      'ستُحذف نسخة التطبيق من الملف مع تعديلاتها. الملف الأصلي على جهازك لن يتأثر.',
      "This deletes RelaxMD's copy of the file, including your edits. The original file on your phone isn't affected.");
  String get openFailed => _t('تعذر فتح الملف', "Couldn't open the file");

  String dateLabel(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final diff = DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (diff == 0) return today;
    if (diff == 1) return yesterday;
    return '${d.day}/${d.month}/${d.year}';
  }

  // Reader
  String get search => _t('بحث', 'Search');
  String get searchHint => _t('ابحث عن كلمة', 'Search for a word');
  String get contents => _t('المحتويات', 'Contents');
  String get noHeadings => _t('لا توجد عناوين', 'No headings');
  String get readingSettings => _t('إعدادات القراءة', 'Reading settings');
  String get resetZoom => _t('إعادة التكبير', 'Reset zoom');
  String get edit => _t('تعديل', 'Edit');
  String get emptyDoc => _t('الملف فارغ. اضغط تعديل للكتابة.', 'This file is empty. Tap Edit to write.');
  String get caseSensitive => _t('مطابقة حالة الأحرف', 'Match case');
  String get wholeWord => _t('كلمة كاملة', 'Whole word');
  String counter(int current, int total) =>
      _t('$current من $total', '$current / $total');

  // Editor
  String get done => _t('تم', 'Done');
  String get undo => _t('تراجع', 'Undo');
  String get redo => _t('إعادة', 'Redo');
  String get findReplace => _t('بحث واستبدال', 'Find and replace');
  String get find => _t('بحث', 'Find');
  String get replaceWith => _t('استبدال بـ', 'Replace with');
  String get replace => _t('استبدال', 'Replace');
  String get replaceAll => _t('الكل', 'All');
  String replaced(int n) => _t('تم استبدال $n', 'Replaced $n');
  String get saved => _t('تم الحفظ', 'Saved');
  String get saving => _t('جارٍ الحفظ…', 'Saving…');
  String words(int w, int c) => _t('$w كلمة · $c حرف', '$w words · $c characters');
  String get editorHint => _t('اكتب بصيغة Markdown…', 'Write in Markdown…');
  String get close => _t('إغلاق', 'Close');
  String get bold => _t('عريض', 'Bold');
  String get italic => _t('مائل', 'Italic');
  String get heading => _t('عنوان', 'Heading');
  String get bulletList => _t('قائمة', 'List');
  String get numberedList => _t('قائمة مرقمة', 'Numbered list');
  String get checkbox => _t('مهمة', 'Checkbox');
  String get quote => _t('اقتباس', 'Quote');
  String get link => _t('رابط', 'Link');
  String get table => _t('جدول', 'Table');
  String get code => _t('كود', 'Code');

  // Reading settings
  String get direction => _t('الاتجاه', 'Direction');
  String get auto => _t('تلقائي', 'Auto');
  String get rtl => _t('يمين', 'RTL');
  String get ltr => _t('يسار', 'LTR');
  String get sensitivity =>
      _t('تأثير الكلمات الإنجليزية', 'Influence of English words');
  String get sensitivityHelp => _t(
      'كلما خفّضته، أصبح السطر من اليمين حتى لو كانت الكلمات الإنجليزية أكثر.',
      'Lower it to keep lines right-to-left even when English words outnumber Arabic ones.');
  String get font => _t('الخط', 'Font');
  String get fontSize => _t('حجم الخط', 'Font size');
  String get fileZoom => _t('تكبير هذا الملف', 'Zoom for this file');
  String get lineSpacing => _t('تباعد الأسطر', 'Line spacing');
  String get margins => _t('الهوامش', 'Margins');
  String get theme => _t('السمة', 'Theme');

  String themeName(String t) => switch (t) {
        'system' => _t('النظام', 'System'),
        'paper' => _t('ورق', 'Paper'),
        'sepia' => _t('بني', 'Sepia'),
        'dim' => _t('داكن', 'Dim'),
        'night' => _t('ليل', 'Night'),
        _ => t,
      };

  String fontName(String f) => switch (f) {
        'Noto Naskh Arabic' => _t('نسخ', 'Naskh'),
        'Amiri' => _t('أميري', 'Amiri'),
        'Cairo' => _t('القاهرة', 'Cairo'),
        'Tajawal' => _t('تجوال', 'Tajawal'),
        _ => f,
      };
}
