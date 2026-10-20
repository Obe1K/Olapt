#!/usr/bin/env python3
"""Операции с App Store Connect API (запускается из .github/workflows/asc-status.yml).

    python3 Tools/asc_ops.py KEY_FILE ISSUER KEY_ID BUNDLE_ID ACTION [ARGS...]

Действия:
    status       — версии и отправки на проверку (как Tools/asc_status.py)
    inspect      — подробно: локализации, наборы скриншотов, сборки, возрастной рейтинг, заметки для ревьюера
    prepare VER BUILD — версии, ожидающей отправки (или отклонённой), дать номер VER, сборку BUILD
                   и тексты из AppStore/asc_texts_VER.json; на проверку НЕ отправляет
    screenshots DIR   — заменить скриншоты iPhone в основной локализации файлами DIR/*.png (по имени)
Ключ не печатается.
"""
import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_check import make_jwt  # noqa: E402

BASE = "https://api.appstoreconnect.apple.com"


class API:
    def __init__(self, key, issuer, kid):
        self.key, self.issuer, self.kid = key, issuer, kid

    def call(self, method, path, body=None):
        token = make_jwt(self.key, self.issuer, self.kid)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(BASE + path, data=data, method=method,
                                     headers={"Authorization": "Bearer " + token,
                                              "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read().decode()
                return r.status, (json.loads(raw) if raw else {})
        except urllib.error.HTTPError as e:
            raw = e.read().decode()
            try:
                return e.code, json.loads(raw)
            except Exception:
                return e.code, {"raw": raw[:500]}

    def get(self, path):
        return self.call("GET", path)


def errors(body):
    return "; ".join("%s: %s" % (e.get("code"), e.get("detail") or e.get("title")) for e in (body or {}).get("errors", []))


def find_app(api, bundle):
    code, body = api.get("/v1/apps?filter[bundleId]=%s&limit=1" % bundle)
    if code != 200 or not body.get("data"):
        raise SystemExit("Приложение не найдено: HTTP %d %s" % (code, errors(body)))
    return body["data"][0]


def inspect(api, app):
    app_id = app["id"]
    print("Приложение: %s (id %s), основной язык: %s" % (app["attributes"].get("name"), app_id,
                                                        app["attributes"].get("primaryLocale")))
    code, body = api.get("/v1/apps/%s/appStoreVersions?limit=5" % app_id)
    for v in body.get("data", []):
        a = v["attributes"]
        print("\nВерсия %s (id %s): %s, releaseType %s" % (a.get("versionString"), v["id"],
                                                        a.get("appVersionState") or a.get("appStoreState"), a.get("releaseType")))
        c, b = api.get("/v1/appStoreVersions/%s/build" % v["id"])
        bd = (b or {}).get("data")
        if bd:
            print("  сборка: %s (id %s)" % (bd["attributes"].get("version"), bd["id"]))
        c, locs = api.get("/v1/appStoreVersions/%s/appStoreVersionLocalizations" % v["id"])
        for loc in locs.get("data", []):
            la = loc["attributes"]
            print("  локализация %s (id %s): описание %d симв., промо %d, ключевые слова %r, что нового %d, support %s, marketing %s"
                  % (la.get("locale"), loc["id"], len(la.get("description") or ""), len(la.get("promotionalText") or ""),
                     la.get("keywords"), len(la.get("whatsNew") or ""), la.get("supportUrl"), la.get("marketingUrl")))
            c, sets = api.get("/v1/appStoreVersionLocalizations/%s/appScreenshotSets" % loc["id"])
            for s in sets.get("data", []):
                c, shots = api.get("/v1/appScreenshotSets/%s/appScreenshots" % s["id"])
                sizes = ["%sx%s" % ((x["attributes"].get("imageAsset") or {}).get("width"),
                                    (x["attributes"].get("imageAsset") or {}).get("height")) for x in shots.get("data", [])]
                print("    скриншоты %s (id %s): %d шт. %s" % (s["attributes"].get("screenshotDisplayType"), s["id"],
                                                          len(sizes), ", ".join(sorted(set(sizes)))))
        c, rd = api.get("/v1/appStoreVersions/%s/appStoreReviewDetail" % v["id"])
        if c == 200 and rd.get("data"):
            ra = rd["data"]["attributes"]
            print("  для ревьюера (id %s): demoAccountRequired=%s, заметки %d симв.: %r"
                  % (rd["data"]["id"], ra.get("demoAccountRequired"), len(ra.get("notes") or ""), (ra.get("notes") or "")[:300]))
    code, body = api.get("/v1/builds?filter[app]=%s&sort=-uploadedDate&limit=6&include=preReleaseVersion" % app_id)
    pre = {i["id"]: i["attributes"].get("version") for i in body.get("included", []) if i["type"] == "preReleaseVersions"}
    print("\nСборки:")
    for b in body.get("data", []):
        a = b["attributes"]
        pv = (b.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}).get("id")
        print("  %s (%s) id %s: %s, шифрование %s, загружена %s, expired %s" % (
            pre.get(pv, "?"), a.get("version"), b["id"], a.get("processingState"), a.get("usesNonExemptEncryption"),
            (a.get("uploadedDate") or "")[:16], a.get("expired")))
    c, infos = api.get("/v1/apps/%s/appInfos" % app_id)
    for inf in infos.get("data", []):
        print("\nAppInfo %s: состояние %s, рейтинг %s" % (inf["id"], inf["attributes"].get("appStoreState") or inf["attributes"].get("state"),
                                                       inf["attributes"].get("appStoreAgeRating")))
        c, ar = api.get("/v1/appInfos/%s/ageRatingDeclaration" % inf["id"])
        if c == 200 and ar.get("data"):
            attrs = {k: v for k, v in ar["data"]["attributes"].items() if v not in (None, "NONE", False)}
            print("  возрастная анкета (id %s): %s" % (ar["data"]["id"], json.dumps(attrs, ensure_ascii=False)))
        c, il = api.get("/v1/appInfos/%s/appInfoLocalizations" % inf["id"])
        for l in il.get("data", []):
            la = l["attributes"]
            print("  %s: name=%r subtitle=%r privacy=%s" % (la.get("locale"), la.get("name"), la.get("subtitle"), la.get("privacyPolicyUrl")))


EDITABLE = {"PREPARE_FOR_SUBMISSION", "REJECTED", "METADATA_REJECTED", "DEVELOPER_REJECTED", "INVALID_BINARY"}


def editable_version(api, app_id):
    code, body = api.get("/v1/apps/%s/appStoreVersions?limit=10" % app_id)
    for v in body.get("data", []):
        st = v["attributes"].get("appVersionState") or v["attributes"].get("appStoreState")
        if st in EDITABLE:
            return v
    raise SystemExit("Нет версии, которую можно менять")


def check_privacy():
    url = "https://obe1k.github.io/Olapt/privacy.html"
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            html = r.read().decode("utf-8", "replace")
        print("Политика конфиденциальности %s: раздел про камеру %s" % (url, "есть" if "камер" in html.lower() else "НЕ НАЙДЕН"))
    except Exception as e:  # noqa: BLE001
        print("Политика конфиденциальности недоступна: %s" % e)


def prepare(api, app, version, build_number):
    app_id = app["id"]
    v = editable_version(api, app_id)
    vid = v["id"]
    old = v["attributes"].get("versionString")
    if old != version:
        code, body = api.call("PATCH", "/v1/appStoreVersions/%s" % vid,
                              {"data": {"type": "appStoreVersions", "id": vid, "attributes": {"versionString": version}}})
        print("Номер версии %s → %s: HTTP %d %s" % (old, version, code, errors(body)))
    code, body = api.get("/v1/builds?filter[app]=%s&filter[version]=%s&filter[preReleaseVersion.version]=%s&limit=1"
                         % (app_id, build_number, version))
    if not body.get("data"):
        raise SystemExit("Сборка %s (%s) не найдена: HTTP %d %s" % (build_number, version, code, errors(body)))
    bid = body["data"][0]["id"]
    code, body = api.call("PATCH", "/v1/appStoreVersions/%s/relationships/build" % vid,
                          {"data": {"type": "builds", "id": bid}})
    print("Сборка %s прикреплена: HTTP %d %s" % (build_number, code, errors(body)))
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AppStore", "asc_texts_%s.json" % version)
    texts = json.load(open(path, encoding="utf-8"))
    code, locs = api.get("/v1/appStoreVersions/%s/appStoreVersionLocalizations" % vid)
    for loc in locs.get("data", []):
        t = texts.get(loc["attributes"]["locale"])
        if not t:
            continue
        code, body = api.call("PATCH", "/v1/appStoreVersionLocalizations/%s" % loc["id"],
                              {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": t}})
        print("Тексты %s: HTTP %d %s" % (loc["attributes"]["locale"], code, errors(body)))
    check_privacy()


DISPLAY_TYPES = {(1320, 2868): "APP_IPHONE_67", (1290, 2796): "APP_IPHONE_67", (1284, 2778): "APP_IPHONE_65",
                 (1242, 2688): "APP_IPHONE_65", (1206, 2622): "APP_IPHONE_61", (1179, 2556): "APP_IPHONE_61"}


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def screenshots(api, app, folder):
    import hashlib
    files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    if not files:
        raise SystemExit("Нет файлов в " + folder)
    size = png_size(os.path.join(folder, files[0]))
    dtype = DISPLAY_TYPES.get(size)
    if not dtype:
        raise SystemExit("Неподходящий размер скриншотов: %dx%d" % size)
    print("Скриншоты: %d шт., %dx%d → %s" % (len(files), size[0], size[1], dtype))
    v = editable_version(api, app["id"])
    primary = app["attributes"].get("primaryLocale")
    code, locs = api.get("/v1/appStoreVersions/%s/appStoreVersionLocalizations" % v["id"])
    loc = next((l for l in locs.get("data", []) if l["attributes"]["locale"] == primary), None)
    if not loc:
        raise SystemExit("Нет локализации " + primary)
    code, sets = api.get("/v1/appStoreVersionLocalizations/%s/appScreenshotSets" % loc["id"])
    target = None
    for st in sets.get("data", []):
        t = st["attributes"]["screenshotDisplayType"]
        if t == dtype:
            target = st["id"]
        elif t.startswith("APP_IPHONE"):
            c, b = api.call("DELETE", "/v1/appScreenshotSets/%s" % st["id"])
            print("Старый набор %s удалён: HTTP %d %s" % (t, c, errors(b)))
    if target:
        c, old = api.get("/v1/appScreenshotSets/%s/appScreenshots" % target)
        for x in old.get("data", []):
            api.call("DELETE", "/v1/appScreenshots/%s" % x["id"])
        print("Старые скриншоты %s удалены: %d" % (dtype, len(old.get("data", []))))
    else:
        c, b = api.call("POST", "/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": dtype},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})
        if c not in (200, 201):
            raise SystemExit("Не удалось создать набор: HTTP %d %s" % (c, errors(b)))
        target = b["data"]["id"]
    ids = []
    for name in files:
        path = os.path.join(folder, name)
        data = open(path, "rb").read()
        c, b = api.call("POST", "/v1/appScreenshots", {"data": {
            "type": "appScreenshots", "attributes": {"fileName": name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": target}}}}})
        if c not in (200, 201):
            print("  %s: резерв не удался HTTP %d %s" % (name, c, errors(b)))
            continue
        sid = b["data"]["id"]
        for op in b["data"]["attributes"].get("uploadOperations", []):
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                         headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])})
            with urllib.request.urlopen(req, timeout=120) as r:
                r.read()
        c, b = api.call("PATCH", "/v1/appScreenshots/%s" % sid, {"data": {
            "type": "appScreenshots", "id": sid,
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print("  %s: HTTP %d %s" % (name, c, errors(b)))
        ids.append(sid)
    if ids:
        c, b = api.call("PATCH", "/v1/appScreenshotSets/%s/relationships/appScreenshots" % target,
                        {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
        print("Порядок скриншотов: HTTP %d %s" % (c, errors(b)))


def main():
    if len(sys.argv) < 6:
        print(__doc__)
        return 2
    key, issuer, kid, bundle, action = sys.argv[1:6]
    api = API(key, issuer, kid)
    app = find_app(api, bundle)
    if action == "inspect":
        inspect(api, app)
    elif action == "prepare":
        prepare(api, app, sys.argv[6], sys.argv[7])
        inspect(api, app)
    elif action == "screenshots":
        screenshots(api, app, sys.argv[6])
    else:
        print("Неизвестное действие: " + action)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
