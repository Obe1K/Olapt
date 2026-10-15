#!/usr/bin/env python3
"""Проверка ключа App Store Connect API без Xcode.

Использование:
    python3 Tools/asc_check.py KEY_FILE.p8 ISSUER_ID KEY_ID [KEY_ID ...]

Для каждого Key ID подписывает JWT ключом из файла и делает запрос
GET https://api.appstoreconnect.apple.com/v1/apps?limit=1.
Печатает по строке на каждый Key ID. Если ключ подошёл, последняя строка
имеет вид "OK <KEY_ID>", и скрипт завершается с кодом 0; иначе код 1.
Только стандартная библиотека и системный openssl; содержимое ключа не печатается.
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request


def b64u(data: bytes) -> bytes:
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def der_to_raw(der: bytes) -> bytes:
    """ECDSA DER (SEQUENCE{INTEGER r, INTEGER s}) -> 64 байта r||s."""
    def read_len(buf, i):
        n = buf[i]
        i += 1
        if n & 0x80:
            k = n & 0x7F
            n = int.from_bytes(buf[i:i + k], "big")
            i += k
        return n, i

    assert der[0] == 0x30
    _, i = read_len(der, 1)
    parts = []
    for _ in range(2):
        assert der[i] == 0x02
        n, i = read_len(der, i + 1)
        parts.append(der[i:i + n].lstrip(b"\x00").rjust(32, b"\x00"))
        i += n
    return parts[0] + parts[1]


def make_jwt(key_file: str, issuer: str, key_id: str) -> str:
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    signing_input = b64u(json.dumps(header, separators=(",", ":")).encode()) + b"." + \
        b64u(json.dumps(payload, separators=(",", ":")).encode())
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_file],
        input=signing_input, capture_output=True, check=True,
    ).stdout
    return (signing_input + b"." + b64u(der_to_raw(der))).decode()


def api_get(key_file: str, issuer: str, key_id: str, path: str) -> tuple:
    """GET к App Store Connect API. Возвращает (HTTP-код или 0, разобранный JSON или None)."""
    try:
        token = make_jwt(key_file, issuer, key_id)
        req = urllib.request.Request("https://api.appstoreconnect.apple.com" + path,
                                     headers={"Authorization": "Bearer " + token})
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, None
    except Exception:
        return 0, None


def probe(key_file: str, issuer: str, key_id: str, bundle_id: str) -> None:
    """Печатает, что видит этот ключ: Bundle ID, карточку приложения, сертификаты, права."""
    checks = [
        ("Bundle ID зарегистрирован", "/v1/bundleIds?filter[identifier]=%s&limit=1" % bundle_id),
        ("Карточка приложения создана", "/v1/apps?filter[bundleId]=%s&limit=1" % bundle_id),
        ("Сертификаты команды", "/v1/certificates?limit=10"),
        ("Устройства команды", "/v1/devices?limit=5"),
        ("Список пользователей (нужна роль Admin)", "/v1/users?limit=1"),
    ]
    for title, path in checks:
        code, body = api_get(key_file, issuer, key_id, path)
        extra = ""
        if code == 200 and body is not None:
            data = body.get("data", [])
            extra = ", найдено: %d" % len(data)
            if "certificates" in path:
                kinds = sorted(set(d.get("attributes", {}).get("certificateType", "?") for d in data))
                extra += " (%s)" % ", ".join(kinds)
        elif body and body.get("errors"):
            extra = " (%s)" % body["errors"][0].get("code", "")
        print("%s: HTTP %d%s" % (title, code, extra))


def check(key_file: str, issuer: str, key_id: str) -> tuple:
    """Возвращает (рабочий?, описание)."""
    try:
        token = make_jwt(key_file, issuer, key_id)
    except Exception as e:  # ключ нечитаем
        return False, "не удалось подписать ключом из файла (%s)" % type(e).__name__
    req = urllib.request.Request(
        "https://api.appstoreconnect.apple.com/v1/apps?limit=1",
        headers={"Authorization": "Bearer " + token},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return True, "HTTP %d, ключ принят" % r.status
    except urllib.error.HTTPError as e:
        try:
            err = json.loads(e.read().decode())["errors"][0]
            text = "%s: %s" % (err.get("code", ""), err.get("title", ""))
        except Exception:
            text = ""
        if e.code == 403:
            return True, "HTTP 403, ключ принят, но роль не даёт доступа (%s)" % text
        return False, "HTTP %d %s" % (e.code, text)
    except Exception as e:
        return False, "сеть: %s" % type(e).__name__


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    key_file, issuer = sys.argv[1], sys.argv[2]
    seen = []
    for i, kid in enumerate(sys.argv[3:]):
        if kid in seen:
            continue
        seen.append(kid)
        ok, msg = check(key_file, issuer, kid)
        label = "из секрета" if i == 0 else "запасной №%d" % i
        print("Key ID (%s), длина %d: %s" % (label, len(kid), msg))
        if ok:
            probe(key_file, issuer, kid, os.environ.get("BUNDLE_ID", ""))
            print("OK " + kid)
            return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
