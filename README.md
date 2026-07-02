# الختمة الإدارية — Flutter App

تطبيق لمتابعة الختمة الإدارية (برنامج أهل شنقيط لختم القرآن كل ٢١ يوماً).

## المميزات

- 📅 **ورد اليوم** — يعرض الأحزاب المقررة لأي يوم تختاره
- 📖 **٨ أثمان** — لكل حزب مع فاتحة كل ثمن قابلة للتوسع
- 🎧 **استمع** — رابط مباشر لليوتيوب (قراءة ورش)
- 📄 **اقرأ** — رابط مباشر لملف PDF من Google Drive
- 🗓️ **معاينة الأسبوع** — عرض سريع لأحزاب الأسبوع كاملاً
- 🌙 **يوم الجمعة** — تذكير بسورة الكهف وحزبان فقط

## الخوارزمية

```
نقطة الارتكاز: ٢٦ مايو ٢٠٢٦ = الأحزاب ٥٩، ٦٠، ١
دورة واحدة = ٢١ يوماً = ٦٠ حزباً
أسبوع = ٢٠ حزباً (٦ أيام × ٣ + الجمعة × ٢)
```

## الإعداد

```bash
# ١. إنشاء مشروع Flutter جديد
flutter create khatma_idariya
cd khatma_idariya

# ٢. استبدال الملفات بملفات المشروع
# (انسخ lib/ و assets/ و pubspec.yaml)

# ٣. تثبيت الحزم
flutter pub get

# ٤. تشغيل التطبيق
flutter run
```

## إعداد Android

في `android/app/src/main/AndroidManifest.xml` أضف داخل `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/>
  </intent>
</queries>
```

## إعداد iOS

في `ios/Runner/Info.plist` أضف:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>https</string>
</array>
```

## هيكل المشروع

```
lib/
├── main.dart
├── theme/
│   └── app_theme.dart          # الألوان والثيم
├── models/
│   └── hizb.dart               # نماذج البيانات
├── services/
│   ├── khatma_calculator.dart  # خوارزمية حساب الورد
│   └── hizb_service.dart       # تحميل JSON
├── screens/
│   ├── home_screen.dart        # الشاشة الرئيسية
│   └── hizb_detail_screen.dart # تفاصيل الحزب
└── widgets/
    ├── hizb_card.dart          # بطاقة الحزب
    └── thumn_tile.dart         # بلاطة الثمن
assets/
└── ahzab.json                  # بيانات ٦٠ حزباً (٤٨٠ ثمن)
```

## الحزم المستخدمة

| الحزمة | الاستخدام |
|--------|-----------|
| `url_launcher` | فتح روابط YouTube و Drive |
| `flutter_localizations` | دعم RTL والعربية |
| `share_plus` | مشاركة الأحزاب |
| `intl` | تنسيق التواريخ |
