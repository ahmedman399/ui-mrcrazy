# MR CRAZY UI LIB

تصميم **Classic Sky** بخط **Ubuntu** ولوجو الدوج بالبكسل وأيقونات بكسل، من غير صور ولا إيموجي، ومن غير أي secret جوه الملفات.

## الاستيراد (سطر واحد)

```lua
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_ui_lib.lua"))()
```

الكي سيستم لوحده (لودر بيحمّل سكريبت اللعبة من السيرفر):

```lua
local KeySystem = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_keysystem.lua"))()
KeySystem.Run({ Version = "1.0.0" })
```

## الملفات

| الملف | فيه إيه |
|---|---|
| `mrcrazy_ui_lib.lua` | **كل حاجة**: النافذة والتابات وكل العناصر، والنوتش (دايناميك ايلاند)، وإشعار الآيلاند، والكي سيستم |
| `mrcrazy_keysystem.lua` | **الكي سيستم لوحده** (نافذة Shy Doge + إشعار الآيلاند + الربط مع الموقع)، بيشتغل من غير المكتبة |
| `example.lua` | **مثال كامل**: بيستورد المكتبة من هنا، الكي سيستم الأول وبعد المفتاح الصح تفتح الواجهة بكل العناصر |
| `AI_GUIDE.md` | **جايد للـ AI**: اديه الملف ده كل ما تطلب منه سكريبت بالمكتبة |
| `docs/LUA-INTEGRATION.md` | دليل الربط مع الموقع |

## شكل أي سكريبت

```lua
local Lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/ahmedman399/ui-mrcrazy/main/mrcrazy_ui_lib.lua"))()

-- ... اللوجيك بتاع اللعبة ...

local function buildUI(session)
    local Win = Lib:CreateWindow({ Title = "MR CRAZY - GAME" })
    Win:CreateTab("Farm", "egg"):CreateToggle("Auto Farm", false, function(on) end)
end

Lib.KeySystem.Run({ Version = "1.0.0", AutoLoad = false, OnSuccess = buildUI })
```

## التجربة
شغّل `example.lua` في الاكسيكيوتر.
- `DEMO = true` (أول الملف): من غير سيرفر. المفتاح `MRC-TEST-TEST-TEST-TEST` بيتقبل، و`MRC-0000-0000-0000-0000` بيطلع "مربوط بجهاز تاني".
- `DEMO = false`: مفاتيح حقيقية من https://mrcrazy.vercel.app/free

> أي تعديل في `mrcrazy_ui_lib.lua` هنا بيوصل لكل السكريبتات تلقائياً (GitHub raw بيعمل كاش حوالي 5 دقايق).

الشرح الكامل لكل الدوال موجود في أول كل ملف وفي `AI_GUIDE.md`.
