# 🔐 GitHub Secrets Registry

## Secrets المستخدمة في المشروع

| # | اسم السر | الاستخدام | أين يُستخدم |
|---|---------|-----------|-------------|
| 1 | `PLAYLIST_URLS` | روابط M3U | build_tv.yml, build_mobile.yml, update_playlists.yml |

---

## 📝 كيف تضيف أو تعدّل سر

1. افتح: `https://github.com/aarcmustafa/forja/settings/secrets/actions`
2. اضغط **New repository secret**
3. في **Name**: اكتب الاسم من الجدول أعلاه
4. في **Secret**: الصق القيمة الحقيقية
5. اضغط **Add secret**

---

## 🎯 ملاحظات

- ✅ الأسماء **حساسة لحالة الأحرف** (كبيرة/صغيرة)
- ✅ القيم مخزّنة **مشفّرة** في GitHub — لا يمكن رؤيتها بعد الحفظ
- ✅ لتفعيل التغيير → شغّل `Update Remote Playlists` من Actions
- ❌ **لا تكتب القيم في أي ملف داخل المستودع**

---

## 📊 سجل التحديثات

| التاريخ | الحدث |
|---------|------|
| 2026-10-14 | إنشاء الملف |
