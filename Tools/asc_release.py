#!/usr/bin/env python3
"""Сертификат и профиль для App Store через App Store Connect API (без Xcode-аккаунта).

Подкоманды:
  setup   KEY_FILE ISSUER KEY_ID BUNDLE_ID OUTDIR
          Создаёт ключ и CSR, выпускает сертификат Apple Distribution и профиль
          IOS_APP_STORE, кладёт в OUTDIR файлы dist.key, cert.cer, profile.mobileprovision
          и env.txt (строки KEY=VALUE: APP_APPLE_ID, CERT_ID, PROFILE_ID, PROFILE_NAME).
  cleanup KEY_FILE ISSUER KEY_ID ENV_FILE
          Удаляет созданные setup профиль и сертификат (идентификаторы берёт из env.txt).

Только стандартная библиотека и системный openssl. Строки "error: ..." подхватывает сводка workflow.
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_check import make_jwt  # noqa: E402

API = "https://api.appstoreconnect.apple.com"


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


def setup(key_file, issuer, key_id, bundle_id, outdir):
    os.makedirs(outdir, exist_ok=True)
    env_path = os.path.join(outdir, "env.txt")
    open(env_path, "w").close()

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

    # 3. Закрытый ключ и запрос на сертификат
    key_path = os.path.join(outdir, "dist.key")
    csr_path = os.path.join(outdir, "dist.csr")
    subprocess.run(
        ["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key_path,
         "-out", csr_path, "-subj", "/CN=OlaPT CI/O=OlaPT/C=UA"],
        check=True, capture_output=True,
    )
    csr = open(csr_path).read()

    # 4. Сертификат Apple Distribution
    code, b = call("POST", "/v1/certificates", {"data": {
        "type": "certificates",
        "attributes": {"certificateType": "DISTRIBUTION", "csrContent": csr},
    }})
    if code not in (200, 201):
        code2, b2 = call("GET", "/v1/certificates?limit=50")
        for d in b2.get("data", []):
            a = d.get("attributes", {})
            print("Существующий сертификат: %s | %s | до %s" % (
                a.get("certificateType"), a.get("name"), a.get("expirationDate")))
        fail("не удалось выпустить сертификат Apple Distribution (HTTP %d)" % code, b)
    cert = b["data"]
    put("CERT_ID", cert["id"])
    with open(os.path.join(outdir, "cert.cer"), "wb") as f:
        f.write(base64.b64decode(cert["attributes"]["certificateContent"]))
    print("Сертификат выпущен")

    # 5. Профиль App Store (устройства не нужны)
    name = "OlaPT CI %s %d" % (os.environ.get("GITHUB_RUN_NUMBER", "0"), int(time.time()))
    code, b = call("POST", "/v1/profiles", {"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle_res_id}},
            "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]},
        },
    }})
    if code not in (200, 201):
        fail("не удалось создать профиль IOS_APP_STORE (HTTP %d)" % code, b)
    prof = b["data"]
    put("PROFILE_ID", prof["id"])
    put("PROFILE_NAME", name)
    with open(os.path.join(outdir, "profile.mobileprovision"), "wb") as f:
        f.write(base64.b64decode(prof["attributes"]["profileContent"]))
    print("Профиль создан")


def cleanup(key_file, issuer, key_id, env_file):
    ids = {}
    try:
        for line in open(env_file):
            if "=" in line:
                k, v = line.rstrip("\n").split("=", 1)
                ids[k] = v
    except OSError:
        print("Нечего удалять: нет файла %s" % env_file)
        return
    for kind, path in (("PROFILE_ID", "profiles"), ("CERT_ID", "certificates")):
        if ids.get(kind):
            code, _ = api(key_file, issuer, key_id, "DELETE", "/v1/%s/%s" % (path, ids[kind]))
            print("Удаление %s: HTTP %d" % (path, code))


def main():
    if len(sys.argv) >= 7 and sys.argv[1] == "setup":
        setup(*sys.argv[2:7])
    elif len(sys.argv) == 6 and sys.argv[1] == "cleanup":
        cleanup(*sys.argv[2:6])
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
