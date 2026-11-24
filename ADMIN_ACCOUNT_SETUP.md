# إعداد Firebase والحسابات الإدارية

مشروع Firebase: `alshaikha`.

## تجهيز الحساب الإداري الأول
1. اربط Firebase CLI بالمشروع `alshaikha` من حساب مالك المشروع.
2. عيّن سر الإعداد الأول خارج المستودع:
   `firebase functions:secrets:set ADMIN_BOOTSTRAP_CODE --project alshaikha`
3. استخدم رمزاً عشوائياً قوياً، ولا تضعه في التطبيق أو GitHub أو المحادثات.
4. انشر وظيفة إنشاء الحساب الإداري:
   `firebase deploy --only functions:createAdminAccount --project alshaikha`
5. انشر قواعد Firestore وStorage:
   `firebase deploy --only firestore:rules,storage --project alshaikha`
6. افتح تطبيق الإدارة واختر «إنشاء أول حساب إداري» ثم أدخل اسم المستخدم وكلمة المرور ورمز الإعداد.
7. بعد إنشاء المدير الأول، يُغلق مسار الإعداد الأول تلقائياً. يستطيع المدير المسجل إنشاء مدراء إضافيين من زر «الحسابات الإدارية».

## قواعد التشغيل
- ملفات `profiles` لا تمنح دور المدير من تطبيق العميل؛ إنشاء المدير يتم عبر Firebase Admin SDK في Cloud Function.
- لا تشارك رمز الإعداد الأول. إذا تسرب، غيّره من Firebase Secret Manager.
- قبل النشر العام، اختبر تسجيل العميل، الحجوزات، الرسائل، الإشعارات، رفع الصور، وتسجيل الخروج على جهاز فعلي.
- لا تنشر تطبيق الإدارة للعامة؛ وزّع APK الإدارة على المسؤولين المصرح لهم فقط.

## النشر من GitHub Actions (بدون إضافة Firebase في ChatGPT)

أُضيف سير عمل يدوي باسم **Deploy Alshaikha Firebase** في تبويب Actions. لن ينشر تلقائياً عند كل تعديل؛ يبدأ فقط عند تشغيله يدوياً وتأكيد اسم المشروع.

### إعداد أسرار المستودع مرة واحدة
1. من Google Cloud Console افتح المشروع `alshaikha` وأنشئ Service Account مخصصاً للنشر.
2. امنحه صلاحيات النشر المطلوبة لخدمات Firebase Functions وCloud Build/Cloud Run وSecret Manager وFirebase Security Rules، مع صلاحية تمرير حساب تشغيل Functions. لا تستخدم حسابك الشخصي ولا تضع ملف المفتاح في المستودع.
3. أنشئ مفتاح JSON لهذا الحساب واحفظه محلياً بأمان.
4. في GitHub افتح المستودع ثم **Settings → Secrets and variables → Actions → New repository secret**.
5. أنشئ السر `FIREBASE_SERVICE_ACCOUNT` والصق محتوى ملف JSON كاملاً كقيمة.
6. أنشئ السر `ADMIN_BOOTSTRAP_CODE` بقيمة عشوائية طويلة وفريدة. احتفظ بها لاستخدامها مرة واحدة في شاشة إنشاء أول مدير. لا تضعها في ملفات المشروع أو المحادثات.

### تشغيل النشر
1. افتح تبويب **Actions** في المستودع.
2. اختر **Deploy Alshaikha Firebase** ثم **Run workflow**.
3. أدخل `alshaikha` حرفياً في حقل التأكيد ثم شغّل العملية.
4. راقب الخطوات حتى تظهر نتيجة نجاح. إذا فشلت المصادقة أو الصلاحيات، افتح سجل الخطوة الفاشلة؛ لا توسّع الصلاحيات عشوائياً.

يشغّل سير العمل إعداد Secret Manager من `ADMIN_BOOTSTRAP_CODE` ثم ينشر Functions وقواعد Firestore وStorage إلى مشروع `alshaikha`. لا تعتبر النشر مكتملاً قبل نجاح جميع الخطوات.
