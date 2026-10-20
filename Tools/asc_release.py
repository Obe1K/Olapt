#!/usr/bin/env python3
"""Сертификат и профиль для App Store через App Store Connect API (без Xcode-аккаунта).

Подкоманды:
  setup   KEY_FILE ISSUER KEY_ID BUNDLE_ID OUTDIR [CACHEDIR]
          Готовит подпись: кладёт в OUTDIR dist.key, cert.cer, cert_id, profile.mobileprovision
          и env.txt (строки KEY=VALUE: APP_APPLE_ID, CERT_ID, CERT_REUSED, PROFILE_ID, PROFILE_NAME).
          Если в CACHEDIR лежит сертификат прошлого запуска (dist.key, cert.cer, cert_id) и он ещё
          действителен, берёт его; иначе выпускает новый сертификат Apple Distribution.
          Профиль App Store с этим сертификатом тоже переиспользуется, если уже есть.
  certs   KEY_FILE ISSUER KEY_ID
          Печатает сертификаты команды (тип, начало id, срок).

Сертификат НЕ отзывается после загрузки: Apple проверяет подпись ещё раз, когда сборку
отправляют на проверку, и сборка, подписанная отозванным сертификатом, получает ITMS-90035
(Invalid Signature). Старый сертификат отзывается, только если Apple не даёт выпустить новый
из-за лимита, и только если ему больше трёх дней.

Только стандартная библиотека и системный openssl. Строки "error: ..." подхватывает сводка workflow.
"""
import base64
import calendar
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_check import make_jwt  # noqa: E402

API = "https://api.appstoreconnect.apple.com"
PROFILE_PREFIX = "OlaPT CI"
# Сертификат или профиль, которому осталось меньше этого срока, заменяется новым
MIN_LEFT = 14 * 86400
# Моложе этого возраста сертификат не отзываем даже при лимите: им может быть подписана сборка на проверке
MIN_AGE_TO_REVOKE = 3 * 86400


def api(key_file, issuer, key_id, method, path, body=None):
    """Запрос к API. Возвращает (HTTP-код или 0, JSON)."""
    token = make_jwt(key_file, issuer, key_id)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        API + path, data=data, method=method,
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw[:300]}
    except Exception as e:
        return 0, {"exception": type(e).__name__}


def fail(message, body=None):
    print("error: " + message)
    if body:
        for err in body.get("errors", []):
            print("error: %s | %s | %s" % (err.get("code", ""), err.get("title", ""), err.get("detail", "")))
        for k in ("exception", "raw"):
            if body.get(k):
                print("error: %s" % body[k])
    sys.exit(1)


def epoch(stamp):
    """«2027-10-20T11:04:00.000+00:00» → секунды UTC (0, если даты нет)."""
    if not stamp:
        return 0
    try:
        return calendar.timegm(time.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S"))
    except ValueError:
        return 0


def day(stamp):
    return (stamp or "")[:10] or "?"


def setup(key_file, issuer, key_id, bundle_id, outdir, cachedir=None):
    os.makedirs(outdir, exist_ok=True)
    env_path = os.path.join(outdir, "env.txt")
    open(env_path, "w").close()
    now = time.time()

    def put(k, v):
        with open(env_path, "a") as f:
            f.write("%s=%s\n" % (k, v))

    def call(method, path, body=None):
        return api(key_file, issuer, key_id, method, path, body)

    # 1. Карточка приложения (нужен числовой Apple ID для загрузки)
    code, b = call("GET", "/v1/apps?filter[bundleId]=%s&limit=10" % bundle_id)
    apps = [d for d in b.get("data", []) if d.get("attributes", {}).get("bundleId") == bundle_id]
    if code != 200 or not apps:
        fail("карточка приложения для %s не найдена (HTTP %d)" % (bundle_id, code), b)
    put("APP_APPLE_ID", apps[0]["id"])
    print("Карточка приложения найдена")

    # 2. Зарегистрированный Bundle ID
    code, b = call("GET", "/v1/bundleIds?filter[identifier]=%s&limit=50" % bundle_id)
    ids = [d for d in b.get("data", []) if d.get("attributes", {}).get("identifier") == bundle_id]
    if code != 200 or not ids:
        fail("Bundle ID %s не зарегистрирован (HTTP %d)" % (bundle_id, code), b)
    bundle_res_id = ids[0]["id"]
    print("Bundle ID найден")

    # 3. Сертификат: из кэша прошлого запуска или новый
    cert_id = reuse_cert(call, cachedir, outdir, now)
    reused = cert_id is not None
    if not reused:
        cert_id = new_cert(call, outdir, now)
    put("CERT_ID", cert_id)
    put("CERT_REUSED", "1" if reused else "0")
    with open(os.path.join(outdir, "cert_id"), "w") as f:
        f.write(cert_id + "\n")

    # 4. Профиль App Store с этим сертификатом (устройства не нужны)
    prof = find_profile(call, bundle_res_id, cert_id, now)
    if prof:
        print("Профиль App Store переиспользован (до %s)" % day(prof["attributes"].get("expirationDate")))
    else:
        name = "%s %s %d" % (PROFILE_PREFIX, os.environ.get("GITHUB_RUN_NUMBER", "0"), int(now))
        code, b = call("POST", "/v1/profiles", {"data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_res_id}},
                "certificates": {"data": [{"type": "certificates", "id": cert_id}]},
            },
        }})
        if code not in (200, 201):
            fail("не удалось создать профиль IOS_APP_STORE (HTTP %d)" % code, b)
        prof = b["data"]
        print("Профиль создан")
    put("PROFILE_ID", prof["id"])
    put("PROFILE_NAME", prof["attributes"]["name"])
    with open(os.path.join(outdir, "profile.mobileprovision"), "wb") as f:
        f.write(base64.b64decode(prof["attributes"]["profileContent"]))


def reuse_cert(call, cachedir, outdir, now):
    """Сертификат прошлого запуска, если он ещё действителен; иначе None."""
    if not cachedir:
        print("Кэша сертификата нет")
        return None
    files = [os.path.join(cachedir, n) for n in ("dist.key", "cert.cer", "cert_id")]
    if not all(os.path.isfile(p) for p in files):
        print("Кэш сертификата неполный")
        return None
    cert_id = open(files[2]).read().strip()
    code, b = call("GET", "/v1/certificates/%s" % cert_id)
    if code != 200:
        print("Сертификат из кэша больше не действует (HTTP %d), выпускаю новый" % code)
        return None
    exp = b["data"]["attributes"].get("expirationDate")
    if epoch(exp) - now < MIN_LEFT:
        print("Сертификат из кэша истекает %s, выпускаю новый" % day(exp))
        return None
    for p in files[:2]:
        shutil.copyfile(p, os.path.join(outdir, os.path.basename(p)))
    os.chmod(os.path.join(outdir, "dist.key"), 0o600)
    print("Сертификат из кэша действует до %s" % day(exp))
    return cert_id


def new_cert(call, outdir, now):
    """Выпускает сертификат Apple Distribution; при лимите отзывает самый старый (если ему > 3 дней)."""
    key_path = os.path.join(outdir, "dist.key")
    csr_path = os.path.join(outdir, "dist.csr")
    subprocess.run(
        ["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key_path,
         "-out", csr_path, "-subj", "/CN=OlaPT CI/O=OlaPT/C=UA"],
        check=True, capture_output=True,
    )
    request = {"data": {
        "type": "certificates",
        "attributes": {"certificateType": "DISTRIBUTION", "csrContent": open(csr_path).read()},
    }}
    code, b = call("POST", "/v1/certificates", request)
    if code not in (200, 201):
        detail = " ".join(e.get("detail", "") for e in b.get("errors", [])).lower()
        limit = any(w in detail for w in ("already have", "maximum", "limit"))
        dist = list_certs(call, "DISTRIBUTION")
        if not (limit and dist):
            fail("не удалось выпустить сертификат Apple Distribution (HTTP %d)" % code, b)
        oldest = min(dist, key=lambda d: epoch(d["attributes"].get("expirationDate")))
        created = epoch(oldest["attributes"].get("expirationDate")) - 365 * 86400
        if now - created < MIN_AGE_TO_REVOKE:
            fail("достигнут лимит сертификатов Apple Distribution, а самому старому меньше трёх дней: "
                 "им может быть подписана сборка на проверке. Удалите лишний вручную "
                 "(developer.apple.com → Certificates) и запустите снова", b)
        print("Лимит сертификатов: отзываю самый старый (до %s)" % day(oldest["attributes"].get("expirationDate")))
        call("DELETE", "/v1/certificates/%s" % oldest["id"])
        code, b = call("POST", "/v1/certificates", request)
        if code not in (200, 201):
            fail("не удалось выпустить сертификат Apple Distribution (HTTP %d)" % code, b)
    cert = b["data"]
    with open(os.path.join(outdir, "cert.cer"), "wb") as f:
        f.write(base64.b64decode(cert["attributes"]["certificateContent"]))
    print("Сертификат выпущен (до %s)" % day(cert["attributes"].get("expirationDate")))
    return cert["id"]


def list_certs(call, kind=None):
    path = "/v1/certificates?limit=200"
    if kind:
        path += "&filter[certificateType]=" + kind
    code, b = call("GET", path)
    return b.get("data", []) if code == 200 else []


def find_profile(call, bundle_res_id, cert_id, now):
    """Действующий профиль «OlaPT CI …» для этого Bundle ID с нашим сертификатом.
    Попутно удаляет недействительные профили «OlaPT CI …» (их сертификат отозван)."""
    code, b = call("GET", "/v1/bundleIds/%s/profiles?limit=200" % bundle_res_id)
    if code != 200:
        return None
    found = None
    removed = 0
    for p in b.get("data", []):
        a = p.get("attributes", {})
        if not a.get("name", "").startswith(PROFILE_PREFIX) or a.get("profileType") != "IOS_APP_STORE":
            continue
        if a.get("profileState") != "ACTIVE":
            c, _ = call("DELETE", "/v1/profiles/%s" % p["id"])
            removed += c in (200, 204)
            continue
        if found or epoch(a.get("expirationDate")) - now < MIN_LEFT or not a.get("profileContent"):
            continue
        c, certs = call("GET", "/v1/profiles/%s/certificates?limit=50" % p["id"])
        if c == 200 and any(d["id"] == cert_id for d in certs.get("data", [])):
            found = p
    if removed:
        print("Удалено устаревших профилей: %d" % removed)
    return found


def certs(key_file, issuer, key_id):
    def call(method, path, body=None):
        return api(key_file, issuer, key_id, method, path, body)
    rows = list_certs(call)
    print("Сертификаты команды: %d" % len(rows))
    for d in sorted(rows, key=lambda d: epoch(d["attributes"].get("expirationDate"))):
        a = d["attributes"]
        print("  %s %s… до %s" % (a.get("certificateType"), d["id"][:6], day(a.get("expirationDate"))))


def main():
    if len(sys.argv) in (7, 8) and sys.argv[1] == "setup":
        setup(*sys.argv[2:])
    elif len(sys.argv) == 5 and sys.argv[1] == "certs":
        certs(*sys.argv[2:5])
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
