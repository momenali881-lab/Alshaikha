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
