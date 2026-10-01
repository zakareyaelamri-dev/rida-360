# RIDA 360° Assessment — Deployment Guide | دليل النشر

نظام تقييم الأداء 360° لشركة الرضا للخدمات الفنية.

---

## المرحلة 1 — تجربة أونلاين فورية (5 دقائق)

1. افتح https://app.netlify.com/drop
2. اسحب ملف `index.html` إلى الصفحة
3. ستحصل على رابط مباشر مثل `https://rida360.netlify.app`

> ⚠️ في هذه المرحلة كل متصفح يحفظ بياناته محلياً — مناسبة للعرض على الإدارة فقط،
> وليست للاستخدام الفعلي متعدد الموظفين.

---

## المرحلة 2 — GitHub + Vercel + Claude Code (التحكم الكامل)

### أ. تثبيت الأدوات (مرة واحدة)
```bash
# يتطلب Node.js 18 أو أحدث من nodejs.org
npm install -g @anthropic-ai/claude-code
```

### ب. فتح المشروع في Claude Code
```bash
cd rida-360        # هذا المجلد
claude
```

### ج. الرفع على GitHub — اطلب من Claude Code حرفياً:
```
Initialize a git repo, create a private GitHub repository named rida-360, and push everything
```
(سيطلب تسجيل دخول GitHub مرة واحدة)

### د. الربط بـ Vercel
1. https://vercel.com → **Continue with GitHub**
2. **Add New → Project** → اختر `rida-360`
3. **Deploy** — الموقع الآن أونلاين
4. كل `git push` قادم = تحديث تلقائي للموقع خلال دقيقة

### هـ. دورة العمل اليومية بعد ذلك
```
claude                        ← افتح Claude Code في المجلد
"عدّل / أضف ..."              ← اطلب أي تغيير بالعربي
"commit and push"             ← انشر التحديث
```

### و. ربط نطاق الشركة (اختياري)
Vercel → Settings → Domains → أضف `assessment.rida-ts.com`
ثم أضف سجل CNAME في إعدادات نطاق `rida-ts.com` كما يرشدك Vercel.

---

## المرحلة 3 — قاعدة بيانات مركزية ✅ مُنجَزة

تم الترحيل: التطبيق يستخدم Supabase (قاعدة بيانات + Auth + RLS)، ولم تعد هناك
كلمات مرور في الكود. ما تبقى من هذا القسم محفوظ كمرجع لكيفية الإعداد من الصفر.

> **تعديلات قاعدة البيانات بعد اليوم تمر عبر migrations، لا عبر لصق
> `supabase_schema.sql` في SQL Editor** — ذاك ملف تثبيت أولي يبدأ بـ`CREATE TABLE`
> وتشغيله على قاعدة حيّة يفشل ويُلغي كل شيء. التفاصيل في
> [`supabase/README.md`](supabase/README.md).

### أ. إنشاء المشروع
1. https://supabase.com → **New project** (الخطة المجانية تكفي للبداية)
2. من **SQL Editor** → الصق محتوى `supabase_schema.sql` → **Run**
3. من **Authentication → Users** أنشئ حساب بريدك، وانسخ الـ UUID
4. نفّذ في SQL Editor:
   `update employees set auth_user = 'UUID-هنا' where id = 'RTS-001';`
5. من **Settings → API** انسخ: `Project URL` و `anon public key`

### ب. الترحيل — اطلب من Claude Code:
```
Migrate this app from window.storage to Supabase.
Project URL: https://xxxx.supabase.co
Anon key: eyJ...
The schema is already applied (see supabase_schema.sql).
Replace the custom login with Supabase Auth email+password,
remove the pw field entirely, and follow the RLS roles described in CLAUDE.md.
Keep the UI and all calculation logic exactly as they are.
```

### ج. إنشاء حسابات الموظفين بعد الترحيل
لكل موظف: Authentication → Add user (بريد + كلمة مؤقتة) → أضف سجله في جدول
employees مع ربط `auth_user`. أو اطلب من Claude Code بناء صفحة
"إنشاء حساب موظف" داخل لوحة الأدمن تقوم بالخطوتين معاً.

---

## ملفات المشروع

| الملف | الغرض |
|-------|-------|
| `index.html` | النظام كاملاً (واجهة + منطق + تخزين) |
| `CLAUDE.md` | تعليمات Claude Code — يقرأها تلقائياً ويفهم بنية المشروع |
| `supabase_schema.sql` | مخطط التثبيت الأولي (مرجع فقط — لا يُشغَّل على قاعدة حيّة) |
| `supabase/migrations/` | ترحيلات قاعدة البيانات — تُطبَّق بـ`supabase db push` |
| `supabase/verify.sql` | فحوص تتأكد أن قواعد السرية والصلاحيات فعّالة على الخادم |
| `supabase/README.md` | سير العمل مع Supabase CLI (تثبيت، ربط، ترحيل، تحقق) |
| `README.md` | هذا الدليل |

---

## الدعم

- توثيق Claude Code: https://docs.claude.com/en/docs/claude-code
- توثيق Supabase: https://supabase.com/docs
- توثيق Vercel: https://vercel.com/docs
