# إعداد الإرسال التلقائي لإشعارات الشيخة دون Firebase Blaze

يستخدم هذا الحل Google Apps Script بجدولة مجانية، ويرسل الإشعارات عبر OneSignal. لا يحتاج إلى نشر Firebase Cloud Functions أو ترقية خطة Firebase.

## 1. إنشاء مشروع Apps Script
1. افتح https://script.google.com وأنشئ مشروعاً جديداً.
2. افتح الملف `Code.gs`.
3. انسخ محتوى الملف `scripts/onesignal_dispatcher.gs` من فرع `onesignal-integration` والصقه في `Code.gs`.

## 2. إضافة المفاتيح بشكل خاص
من إعدادات المشروع افتح **Project Settings → Script Properties** وأضف:

| الاسم | القيمة |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | محتوى ملف Service Account JSON الخاص بمشروع Firebase |
| `ONESIGNAL_CLIENT_REST_API_KEY` | REST API Key لتطبيق العميل في OneSignal |
| `ONESIGNAL_ADMIN_REST_API_KEY` | REST API Key لتطبيق الإدارة في OneSignal |
| `FIREBASE_PROJECT_ID` | `alshaikha` |

لا ترسل هذه القيم في المحادثة ولا تضعها في ملفات التطبيق أو GitHub. لا تشارك مشروع Apps Script مع أشخاص آخرين.

## 3. تفعيل الجدولة
1. اختر الدالة `setupAlshaikhaNotifications`.
2. اضغط **Run** ووافق على الأذونات المطلوبة.
3. ستنشأ مهمة تلقائية تعمل كل دقيقة وتفحص الإشعارات الجديدة.

يجب أن يمتلك حساب الخدمة صلاحية قراءة وتحديث مستندات Firestore. إذا ظهر خطأ صلاحيات، أضف له دور **Cloud Datastore User** في IAM بمشروع Firebase.

## كيف يعمل؟
- تطبيق العميل والإدارة يضيفان الإشعارات إلى مجموعة `notifications` مع حالة `pushStatus=pending`.
- Apps Script يقرأ الإشعارات المعلّقة، ويختار تطبيق OneSignal الصحيح حسب `target`.
- عند نجاح الإرسال يغيّر الحالة إلى `sent`. وإذا لم يوجد مشتركون يسجل `no_recipients`.
- المفاتيح السرية تبقى في Script Properties ولا تدخل ملفات APK.

ملاحظة: Google Apps Script مجاني ضمن حدود الاستخدام والحصص التي تفرضها Google؛ الجدولة ليست ضماناً لوصول فوري بالثانية.
