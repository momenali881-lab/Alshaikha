# إعداد الإرسال التلقائي لإشعارات الشيخة دون Firebase Blaze

يستخدم هذا الحل Google Apps Script وOneSignal، ولا يحتاج إلى نشر Firebase Cloud Functions أو ترقية خطة Firebase إلى Blaze.

## 1. إنشاء مشروع Apps Script
1. افتح https://script.google.com وأنشئ مشروعاً جديداً.
2. افتح الملف `Code.gs`.
3. انسخ محتوى الملف `scripts/onesignal_dispatcher.gs` من فرع `feature/notifications-speed-display-2026-11-25` والصقه بالكامل في `Code.gs`.

## 2. إضافة المفاتيح بشكل خاص
من إعدادات المشروع افتح **Project Settings → Script Properties** وأضف:

| الاسم | القيمة |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | محتوى ملف Service Account JSON الخاص بمشروع Firebase |
| `ONESIGNAL_CLIENT_REST_API_KEY` | REST API Key لتطبيق العميل في OneSignal |
| `ONESIGNAL_ADMIN_REST_API_KEY` | REST API Key لتطبيق الإدارة في OneSignal |
| `FIREBASE_PROJECT_ID` | `alshaikha` |

لا ترسل هذه القيم في المحادثة ولا تضعها في ملفات التطبيق أو GitHub. لا تشارك مشروع Apps Script مع أشخاص آخرين.

## 3. تفعيل الجدولة الاحتياطية
1. اختر الدالة `setupAlshaikhaNotifications`.
2. اضغط **Run** ووافق على الأذونات المطلوبة.
3. ستنشأ مهمة تلقائية تعمل كل دقيقة كمسار احتياطي إذا تعذر الاتصال الفوري.

## 4. تفعيل الإرسال الفوري بعد حفظ الإشعار
1. من **Deploy → New deployment** اختر **Web app**.
2. اجعل **Execute as** هو حسابك، و **Who has access** هو **Anyone**. نقطة الويب تتحقق من Firebase ID token ومن دور المستخدم وعلاقته بالإشعار قبل الإرسال؛ لا تعتمد على رابط الويب وحده كوسيلة حماية.
3. اضغط **Deploy** وانسخ رابط Web app الذي ينتهي بـ `/exec`.
4. في GitHub افتح المستودع ثم **Settings → Secrets and variables → Actions → New repository secret**.
5. اجعل اسم السر `ALSHAIKHA_NOTIFICATION_WEBHOOK_URL`، والصق رابط Web app في خانة القيمة.
6. شغّل بناء Android من فرع `feature/notifications-speed-display-2026-11-25` بعد إضافة السر، ثم ثبّت APK العميل والإدارة الناتجين.

مفتاح Firebase Web API الموجود في إعداد التطبيق مفتاح تعريف عام للمشروع، ويُستخدم فقط للتحقق من Firebase ID token. لا تضع Service Account JSON أو مفاتيح OneSignal REST في GitHub أو داخل التطبيق.

يجب أن يمتلك حساب الخدمة صلاحية قراءة وتحديث مستندات Firestore. إذا ظهر خطأ صلاحيات، أضف له دور **Cloud Datastore User** في IAM بمشروع Firebase.

## كيف يعمل؟
- بعد حفظ إشعار جديد في Firestore، يرسل التطبيق طلباً فورياً إلى Web app مع Firebase ID token ومعرّف الإشعار فقط.
- يتحقق Apps Script من هوية المستخدم وصلاحيته، ثم يرسل الإشعار عبر OneSignal مباشرة.
- تبقى مهمة الدقيقة الواحدة كمسار احتياطي، مع تخزين رمز Firebase المؤقت لتقليل طلبات المصادقة.
- عنوان الإشعار للعميل هو **الشيخة**، ويظهر جزء من نص الرسالة أو تفاصيل الحجز أو الإعلان في محتوى الإشعار.
- تستخدم الإشعارات صورة صاحب الرسالة عند توفر رابط عام صالح، وإلا تستخدم أيقونة علامة الشيخة المحسّنة.
- تستخدم التطبيقات قناة Android جديدة ذات أهمية عالية لعرض التنبيه المنبثق.

ملاحظة: الإرسال الفوري يعتمد على نجاح اتصال التطبيق بالـ Web app والإنترنت؛ وتبقى جدولة الدقيقة الواحدة احتياطاً. ظهور النافذة المنبثقة يعتمد أيضاً على سماح Android بإظهار التنبيهات المنبثقة لهذه القناة وعلى إعدادات عدم الإزعاج.
