# MR CRAZY — Lua script integration guide

> For the developer of the MR CRAZY Lua script that runs inside the executor (Windows / Android / iOS).
> Everything you need: how to talk to the server, how a player activates a key, how the HWID is bound, and what to avoid.
> Last updated: October 9, 2026.

---

## 0. TL;DR

1. **You don't need any Supabase access** (no service key, no anon key, no dashboard). All you need is **one public HTTPS endpoint** (`app-api`) built specifically for the script.
2. The player pastes their key (`MRC-XXXX-XXXX-XXXX-XXXX`) → the script sends it to `/activate` → the server **binds the key to the first device** that activates it.
3. **The server reads the HWID by itself** from the `*-Fingerprint` header that the executor automatically adds to every `request()`. Also send `hwid` in the body as a **fallback** for executors that don't send that header.
4. When the player joins a game → fetch that game's script from `/script` by `PlaceId` and run it.
5. **Never** put any secret (server key/token/password) inside the script — players can read anything inside a Lua script.

### Why no Supabase access?
The script is downloaded onto players' devices, so any key inside it is **public**. If a Supabase key were in it, anyone could read or change the database. That's why:
- The database is fully locked (RLS), and keys can't be read through the API by anyone.
- The script only talks to an **Edge Function** called `app-api`, which does every check on the server (key, device, plan, ban, rate limit) and returns the result.
- Even if someone decompiles the script and reads every line, there's nothing useful to steal.

---

## 1. The API

**Base URL:**
```
https://yarmjpvakthxvvqarxwq.supabase.co/functions/v1/app-api
```
- Every request is `Content-Type: application/json` and responses are JSON (except the script itself: plain Lua text).
- No `Authorization` or `apikey` headers — you don't need them.
- This URL stays the same even if the website changes its domain.

### 1.1 `GET /info` — app status (no key needed)
```json
{ "ok": true, "app_version": "1.0.0",
  "downloads": { "windows": null, "android": null, "ios": null },
  "maintenance": false }
```
- `maintenance = true` → show "Under maintenance" and stop.
- `app_version` → if it's newer than your script's version, show "Update available".

### 1.2 `POST /activate` — activate / check a key
**Request:**
```json
{ "key": "MRC-ABCD-EFGH-JKLM-NPQR", "hwid": "<fallback device id>" }
```
**200 — success:**
```json
{ "ok": true, "plan": "free", "expires_at": "2026-10-10T07:36:37Z",
  "games": [ { "slug": "blox-fruits", "name": "Blox Fruits", "version": "1.0.0",
               "status": "working", "access": "free", "place_ids": [2753915549] } ],
  "game": null }
```
- `plan`: `free` (24-hour key) or `premium` (permanent, `expires_at = null`).
- `games`: only the games this key can run (Free = free games, Premium = all). `status`: `working` / `updating` / `patched`.
- **The first successful activation binds the key to the device.** After that, any other device gets `hwid_mismatch`.

**403 — rejected:** `{ "ok": false, "error": "<code>" }` (codes in §1.4).

### 1.3 `POST /script` — download a game's script
**Request:**
```json
{ "key": "MRC-…", "hwid": "<fallback>", "game": "2753915549" }
```
- `game` = the current game's **PlaceId** (`tostring(game.PlaceId)`) or its slug (`"blox-fruits"`).
- The server runs the same checks as `/activate` every time (key + device + plan + game).

**200** → the script text (Lua) — run it with `loadstring`.
**403 / 404** → `{ "ok": false, "error": "<code>" }`.

### 1.4 Error codes — and what to show the player
| `error` | HTTP | Meaning | Suggested message |
|---|---|---|---|
| `invalid_key` | 403 | Key doesn't exist | `Key not found. Copy it again from mrcrazy.xyz/profile` |
| `expired` | 403 | Free key ran out (24 h) | `Your free key expired. Get a new one at mrcrazy.xyz/free` |
| `revoked` | 403 | Key was turned off (or Premium was removed) | `This key was turned off. Check your profile on the site.` |
| `banned` | 403 | Account is banned | `Your account is suspended.` |
| `hwid_mismatch` | 403 | Key is bound to another device | `This key is linked to another device. Premium: use "Reset device" on your profile.` |
| `premium_only` | 403 | Premium game with a Free key | `This game is for Premium players.` |
| `game_not_found` | 403 | Game isn't supported (or is hidden) | `This game isn't supported yet.` |
| `script_file_missing` | 404 | Game exists but its script file isn't uploaded yet | `This script is being updated. Try again soon.` |
| `bad_request` | 400 | Missing `key`, or no HWID at all | (a bug in the script — check your code) |
| `rate_limited` | 429 | Too many requests | `Slow down and try again in a minute.` |
| `server_error` | 500 | Problem on our side | `Something went wrong. Try again.` |

**Rate limits per IP:** `/activate` 30 requests/min · `/script` 60 requests/min. Don't call the server in a tight loop.

---

## 2. The HWID — how it works and what's right

### 2.1 Where the real HWID comes from inside an executor
Luau has **no access to hardware** (no serials, no MAC, no registry). Only **the executor itself** (native C++/Java/Swift code) can read hardware. Executors that follow the **sUNC** standard do this automatically:

> Every `request()` is sent with headers the executor adds:
> - **`<PREFIX>-Fingerprint`** — a hardware-bound HWID of the device (this is what we want).
> - `<PREFIX>-User-Identifier` — a user ID that is **the same on all of that user's devices** (not a device ID — don't use it).
> - `User-Agent` — the executor's name and version.
>
> `PREFIX` differs per executor (e.g. `Delta-Fingerprint`, `Fluxus-Fingerprint`…).
> Reference: [sUNC — request](https://docs.sunc.io/Miscellaneous/request/)

**The server (`app-api`) looks for any header whose name ends in `-Fingerprint` and uses it as the HWID**, ignoring the body's `hwid`. This is much better than computing the HWID in the script, because:
- The value comes from native code inside the executor (actually tied to the hardware), not from Lua.
- The script can't easily "invent" a different value (the header is added after the script sends the request).
- You don't need to write any hardware code at all.

**What you must do:** use `request()` (or your executor's alias for it) for every call — **not** `game:HttpGet` — so these headers get sent.

### 2.2 The fallback (if the executor doesn't send a Fingerprint)
Send `hwid` in the body, in this order:
1. **`gethwid()`** — if the executor provides it (not standard; some executors have it, some don't). Returns a native fingerprint like the header.
2. **`game:GetService("RbxAnalyticsService"):GetClientId()`** — last resort. This is a Roblox client ID, not hardware, and it **can change** with Roblox updates or reinstalls → the player would need a reset. Only use it if nothing else exists.
3. If none are available → show `This executor isn't supported` (the server returns `bad_request` when there's no HWID at all).

> Important: **don't change the HWID source after launch.** If you do, every player gets `hwid_mismatch` at once.

### 2.3 Never use these as the HWID
| Identifier | Why not |
|---|---|
| **MAC address** | Not reachable from Luau anyway; on Android 6+ and iOS 7+ it returns a fixed fake value (`02:00:00:00:00:00`); modern phones randomize it per network; easy to change on Windows. |
| **IP address** | Changes with every network / router / VPN / mobile data. |
| `Player.UserId` / `Player.Name` | That's a **Roblox account**, not a device — someone shares their account and the key works for both. |
| The `*-User-Identifier` header | Per the standard it's **the same on all of a user's devices** — doesn't stop sharing. |
| A random UUID saved with `writefile` | A normal file: the player can delete it or copy it to a friend → the key works on any device. |
| `HttpService:GenerateGUID()` / `os.time()` / `tick()` | Different every time. |
| Executor name/version (`identifyexecutor()`) | Changes with every executor update. |
| Any **software** value that changes on its own (computer name, Windows username, locale, timezone…) | Easy to change and not unique. |

### 2.4 Windows / Android / iOS — what to expect per platform
The executor computes the Fingerprint, but this is what each OS makes available (so you understand how stable the value is):

- **Windows** — real hardware identifiers exist (SMBIOS UUID, motherboard/disk serials). The value is **usually stable**; it changes if a core part is replaced, and sometimes after reinstalling Windows.
- **Android** — since Android 10, IMEI and serial are **blocked** for normal apps. What's available: `ANDROID_ID` (since Android 8 scoped to app + user + device, and **changes on factory reset**) or the Widevine ID (`MediaDrm`). So a player may need a reset after wiping their phone.
- **iOS** — Apple **gives apps no hardware ID** (UDID was removed in iOS 7). What's available: `identifierForVendor` (changes if all of that developer's apps are removed) or a UUID stored in the Keychain. So on iOS the value may change when the executor is reinstalled.

**That's why our system works like this:**
- **Free:** no reset — the key only lasts 24 hours, and the player gets a new key from the website on the new device.
- **Premium:** a **Reset device** button on the Profile page — **3 times for life**. It unbinds the device from the key, and the first device that activates it afterwards gets bound. Admins can give a player their 3 resets back from the admin panel if something goes wrong.
- As the developer you don't need to do anything for resets — they happen on the website only. Just show the clear `hwid_mismatch` message above.

---

## 3. The flow

```
Script starts
   │
   ├─ GET /info ── maintenance? → message and stop
   │
   ├─ Saved key (readfile)? ── no → show an "Enter key" box + a "Get key" button (opens the website)
   │
   ├─ POST /activate {key, hwid}
   │     ├─ ok → save the key (writefile), show the plan + games
   │     └─ error → show the message (§1.4). For invalid_key / expired / revoked → delete the saved key and ask for a new one
   │
   └─ In a game → POST /script {key, hwid, game = PlaceId}
         ├─ 200 → loadstring(body)()
         └─ error → show the message
```
- Call `/activate` **once at startup**. No need to check every minute — `/script` re-checks the key every time.
- For long sessions where you want to make sure a free key hasn't expired: checking **once an hour** is enough.

---

## 4. Ready-to-use code (Lua — executor)

```lua
-- MR CRAZY · auth + script loader
local HttpService = game:GetService("HttpService")

local API = "https://yarmjpvakthxvvqarxwq.supabase.co/functions/v1/app-api"
local SITE = "https://mrcrazy.xyz"
local FOLDER = "MRCRAZY"
local KEY_FILE = FOLDER .. "/key.txt"
local KEY_PATTERN = "^MRC%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w$"

-- request() is the sUNC standard; the others are older aliases in some executors
local httpRequest = request or http_request or (syn and syn.request) or (http and http.request)

local MESSAGES = {
	invalid_key = "Key not found. Copy it again from " .. SITE .. "/profile",
	expired = "Your free key expired. Get a new one at " .. SITE .. "/free",
	revoked = "This key was turned off. Check your profile on the site.",
	banned = "Your account is suspended.",
	hwid_mismatch = 'This key is linked to another device. Premium: use "Reset device" on your profile.',
	premium_only = "This game is for Premium players.",
	game_not_found = "This game isn't supported yet.",
	script_file_missing = "This script is being updated. Try again soon.",
	rate_limited = "Slow down and try again in a minute.",
}

local function message(code)
	return MESSAGES[code] or "Something went wrong. Try again."
end

-- Fallback only: the server takes the HWID from the "*-Fingerprint" header the executor adds by itself.
local function fallbackHwid()
	if type(gethwid) == "function" then
		local ok, id = pcall(gethwid)
		if ok and type(id) == "string" and #id > 0 then
			return id
		end
	end
	local ok, id = pcall(function()
		return game:GetService("RbxAnalyticsService"):GetClientId()
	end)
	if ok and type(id) == "string" and #id > 0 then
		return id
	end
	return nil
end

-- Returns: status, data (decoded JSON or nil), raw body
local function call(method, route, body)
	local ok, response = pcall(httpRequest, {
		Url = API .. "/" .. route,
		Method = method,
		Headers = { ["Content-Type"] = "application/json" },
		Body = body and HttpService:JSONEncode(body) or nil,
	})
	if not ok or not response then
		return 0, nil, ""
	end
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body or "")
	return response.StatusCode, decoded and data or nil, response.Body or ""
end

local function savedKey()
	if isfile and isfile(KEY_FILE) then
		return (readfile(KEY_FILE):gsub("%s+", ""))
	end
	return nil
end

local function saveKey(key)
	if not writefile then return end
	if makefolder and isfolder and not isfolder(FOLDER) then
		makefolder(FOLDER)
	end
	writefile(KEY_FILE, key)
end

local function forgetKey()
	if delfile and isfile and isfile(KEY_FILE) then
		delfile(KEY_FILE)
	end
end

local Auth = {}

-- Maintenance flag + app version
function Auth.info()
	local status, data = call("GET", "info")
	if status == 200 and data then
		return data
	end
	return nil
end

-- Returns data on success, or nil + a message for the player
function Auth.activate(key)
	key = string.upper((key or ""):gsub("%s+", ""))
	if not key:match(KEY_PATTERN) then
		return nil, message("invalid_key")
	end
	local status, data = call("POST", "activate", { key = key, hwid = fallbackHwid() })
	if status == 200 and data and data.ok then
		saveKey(key)
		return data
	end
	local code = data and data.error or "server_error"
	if code == "invalid_key" or code == "expired" or code == "revoked" then
		forgetKey()
	end
	return nil, message(code)
end

-- Runs the script for the current game
function Auth.runCurrentGame(key)
	local status, data, raw = call("POST", "script", {
		key = key,
		hwid = fallbackHwid(),
		game = tostring(game.PlaceId),
	})
	if status ~= 200 then
		return false, message(data and data.error)
	end
	local chunk, compileError = loadstring(raw)
	if not chunk then
		return false, "Script error: " .. tostring(compileError)
	end
	task.spawn(chunk)
	return true
end

-- ===== Usage =====
if not httpRequest then
	warn("[MR CRAZY] This executor isn't supported (no request function).")
	return
end

local info = Auth.info()
if info and info.maintenance then
	warn("[MR CRAZY] Under maintenance. Try again later.")
	return
end

local key = savedKey() -- or the value the player typed into your UI
if not key then
	warn("[MR CRAZY] Enter your key. Get one at " .. SITE)
	return -- show your key-entry UI here; when they press Activate, call Auth.activate(text)
end

local session, err = Auth.activate(key)
if not session then
	warn("[MR CRAZY] " .. err)
	return
end
print(("[MR CRAZY] %s key active · %d games"):format(session.plan, #session.games))

local ok, runError = Auth.runCurrentGame(key)
if not ok then
	warn("[MR CRAZY] " .. runError)
end
```

**Notes on the code:**
- `writefile` stores the key in the executor's workspace folder. That's safe because the key is bound to the device — if it's stolen it won't work on another device.
- **Never print the full key** to the console or to any public webhook/log. If you need to show it, show only the last 4 characters.
- The PlaceId is matched against the game's `place_ids` in the admin panel — if a game has several places (lobby / match), the admin must add all of them.

---

## 5. Don'ts (security)
- ❌ Any server or Supabase key/token/secret inside the script.
- ❌ Talking to the database or Supabase REST directly — `app-api` only.
- ❌ Deciding key validity in the script (e.g. comparing dates) — the server decides; the script only shows the result.
- ❌ Sending requests in a fast loop (you'll get `rate_limited`).
- ❌ Changing the HWID source after launch.
- ✅ If you want to protect the script from being read, obfuscate it — that's a nice extra, but the real protection is on the server.

---

## 6. How to test
1. Get a Free key from the website: `https://mrcrazy.xyz/free` (sign in → the 3 checkpoints). The key shows on `/profile`.
2. Try these scenarios — the results must match exactly:

| Scenario | Expected |
|---|---|
| Valid key, first time | `ok` + the key gets bound to the device (the website shows "Device linked") |
| Same key from another device / executor | `hwid_mismatch` |
| Wrong key | `invalid_key` |
| Free key after 24 hours | `expired` |
| Free key on a Premium game | `premium_only` |
| Unknown game | `game_not_found` |
| Premium: Reset device on the website → activate from a new device | `ok` on the new one · `hwid_mismatch` on the old one |

3. Quick test without Roblox (curl):
```bash
curl https://yarmjpvakthxvvqarxwq.supabase.co/functions/v1/app-api/info
curl -X POST -H "Content-Type: application/json" -d '{"key":"MRC-XXXX-XXXX-XXXX-XXXX","hwid":"test-device"}' https://yarmjpvakthxvvqarxwq.supabase.co/functions/v1/app-api/activate
```
> ⚠️ Any successful activation binds the key to the HWID that was sent. Don't test with a real player's key from curl.

---

## 7. Appendix — if you ever build a native app (not an executor)
If a standalone app is built (exe / apk / ipa) that reads the hardware itself, these are the best sources per OS. **Send a hash of the value** (e.g. `SHA-256(value + app_name)`), not the raw value.

| OS | Use | Avoid |
|---|---|---|
| **Windows** | SMBIOS UUID (`Win32_ComputerSystemProduct.UUID` via WMI) + `MachineGuid` from `HKLM\SOFTWARE\Microsoft\Cryptography` — both combined. If the UUID is all zeros/`FFFF…` (happens on some boards), use `MachineGuid` alone. | MAC · volume serial (changes on format) · computer name · `ProcessorId` (same value for every CPU of the same model) |
| **Android** | `Settings.Secure.ANDROID_ID` (stable for the same app and signing key; changes on factory reset or if the APK signing key changes). Optional: the Widevine ID from `MediaDrm` as an extra signal (not available on every device, and some cheap devices share the same value). | IMEI / serial (blocked since Android 10) · MAC (fake/randomized) · Advertising ID (the user can reset it) |
| **iOS** | A UUID you generate on first run and store in the **Keychain** with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (survives app deletion and isn't restored to another device from a backup). Or `identifierForVendor`. | UDID (removed) · MAC (fake) · IDFA (needs ATT permission and is often zeros) |

Whatever the source, no HWID is guaranteed never to change — that's why Premium has resets and admins can unlink a device manually from `/admin/keys`.

---

## 8. Research sources
- [sUNC — `request` (the Fingerprint / User-Identifier headers)](https://docs.sunc.io/Miscellaneous/request/)
- [sUNC — `identifyexecutor`](https://docs.sunc.io/Miscellaneous/identifyexecutor/)
- [PandaAuth — HWID locking explained](https://pandauth.com/blog/hwid-security-explained) (reset policy and server-side binding)
- [WeAreDevs — getting the HWID from Luau](https://forum.wearedevs.net/t/33788) (Luau has no hardware access, and `GetClientId` isn't stable)
- [Android — Settings.Secure.ANDROID_ID](https://learn.microsoft.com/ja-jp/dotnet/api/android.provider.settings.secure.androidid)
- [Talsec — choosing the best Android device ID](https://docs.talsec.app/appsec-articles/articles/fraud-proofing-an-android-app-choosing-the-best-device-id-for-promo-abuse-prevention)
- [Verimatrix — how DRMs identify devices (Widevine L1/L3)](https://docs.verimatrix.com/docs/how-are-devices-counted-by-the-system)
