# الختمة الإدارية — نسخة القراءة للويب (ready)

موقع ثابت (static) لعرض **ورد اليوم**: الأحزاب والأثمان لأي تاريخ، مع **اقرأ** (المصحف PDF
بعارض المتصفح الأصلي) و**استمع** (تلاوة يوتيوب مدمجة). لا خادم تطبيقات، لا تسجيل دخول، لا تتبّع.

## المحتويات
| الملف | الوصف |
|------|-------|
| `index.html` | الصفحة |
| `styles.css` | الثيم (ألوان التطبيق، RTL) |
| `calculator.js` | خوارزمية الورد (منقولة من `khatma_calculator.dart`) |
| `data.js` | بيانات الأحزاب الـ٦٠ + الأثمان + روابط يوتيوب |
| `app.js` | منطق الواجهة |
| `share.js` | توليد صورة الورد (Canvas) + المشاركة الاجتماعية |
| `favicon.png` | أيقونة التطبيق |
| `pdf/1.pdf … 60.pdf` | مصاحف الأحزاب (تُقرأ محلياً) |

## المشاركة (جديد)
- **📸 صورة الورد:** تُولّد صورة PNG أنيقة (ترويسة خضراء + التاريخ واضحاً + الأحزاب الثلاثة مع السور والآيات)
  مع أزرار: مشاركة الصورة (Web Share)، تحميل، واتساب، فيسبوك، تويتر.
- التاريخ والأحزاب الثلاثة تظهر في **صفحة واحدة** دون تمرير.

## القراءة (اقرأ)
- **سطح المكتب:** نافذة قراءة تملأ الشاشة بعارض PDF الأصلي للمتصفح (تمرير/تكبير).
- **الهاتف:** يُفتح المصحف في تبويب جديد (أفضل عرض على المتصفحات المحمولة).
- المصدر: ملف محلي `pdf/<رقم الحزب>.pdf` — لا اعتماد على Google Drive.

## النشر على الخادم (Apache — DocumentRoot = /var/www/html/khatma)
من جهازك المحلي (PowerShell)، ارفع المجلد إلى الخادم مؤقتاً:
```powershell
scp -r "web_read" root@84.238.132.122:/tmp/
```
ثم على الخادم:
```bash
cp -r /tmp/web_read/* /var/www/html/khatma/
chown -R www-data:www-data /var/www/html/khatma
rm -rf /tmp/web_read
```
تحقّق:
```bash
curl -sI http://khatma-idara.online/pdf/1.pdf   # Content-Type: application/pdf
```
افتح http://khatma-idara.online في نافذة خفية (لتجاوز الكاش القديم).

## تحديث البيانات
عند تغيير `assets/ahzab.json` أو ملفات `assets/pdf/`، أعد توليد `data.js` وانسخ الـPDF:
```bash
python -c "import json,io; d=json.load(io.open('assets/ahzab.json',encoding='utf-8-sig')); io.open('web_read/data.js','w',encoding='utf-8').write('window.AHZAB = '+json.dumps(d,ensure_ascii=False)+';')"
cp assets/pdf/*.pdf web_read/pdf/
```

## ملاحظة الخوارزمية
نقطة الارتكاز: **١ يوليو ٢٠٢٦ = الأحزاب ١٩، ٢٠، ٢١** (مطابقة للكود في `khatma_calculator.dart`).
