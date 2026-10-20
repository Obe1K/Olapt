#!/usr/bin/env python3
"""Операции с App Store Connect API (запускается из .github/workflows/asc-status.yml).

    python3 Tools/asc_ops.py KEY_FILE ISSUER KEY_ID BUNDLE_ID ACTION [ARGS...]

Действия:
    status   — версии и отправки на проверку (как Tools/asc_status.py)
    inspect  — подробно: локализации, наборы скриншотов, сборки, возрастной рейтинг, заметки для ревьюера
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


def main():
    if len(sys.argv) < 6:
        print(__doc__)
        return 2
    key, issuer, kid, bundle, action = sys.argv[1:6]
    api = API(key, issuer, kid)
    app = find_app(api, bundle)
    if action == "inspect":
        inspect(api, app)
    else:
        print("Неизвестное действие: " + action)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
