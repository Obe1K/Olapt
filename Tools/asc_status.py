#!/usr/bin/env python3
"""Статус версий и отправок на проверку в App Store Connect (без Xcode).

Использование:
    python3 Tools/asc_status.py KEY_FILE.p8 ISSUER_ID KEY_ID BUNDLE_ID

Печатает версии приложения с их состоянием и последние отправки на проверку (Review Submissions)
с элементами внутри. Ключ не печатается. Сообщения ревьюера через API недоступны —
их видно только в App Store Connect (App Review → сообщения).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_check import api_get  # noqa: E402

STATES_RU = {
    # reviewSubmissions.state
    "READY_FOR_REVIEW": "готово к отправке (ещё не отправлено)",
    "WAITING_FOR_REVIEW": "в очереди на проверку",
    "IN_REVIEW": "идёт проверка",
    "UNRESOLVED_ISSUES": "есть нерешённые замечания — ждут ответа или повторной отправки от разработчика",
    "CANCELING": "отменяется",
    "COMPLETING": "завершается",
    "COMPLETE": "проверка завершена",
    # appStoreVersions.appStoreState / appVersionState
    "PREPARE_FOR_SUBMISSION": "готовится к отправке",
    "REJECTED": "отклонено",
    "METADATA_REJECTED": "отклонены метаданные",
    "DEVELOPER_REJECTED": "снято разработчиком",
    "PENDING_DEVELOPER_RELEASE": "одобрено, ждёт ручного выпуска",
    "READY_FOR_SALE": "в продаже",
    "READY_FOR_DISTRIBUTION": "в продаже",
    "ACCEPTED": "одобрено",
    "PROCESSING_FOR_DISTRIBUTION": "одобрено, готовится к выпуску",
    "INVALID_BINARY": "сборка не принята",
    # reviewSubmissionItems.state
    "APPROVED": "одобрено",
    "REMOVED": "убрано из отправки",
}


def ru(state):
    return "%s (%s)" % (state, STATES_RU.get(state, "?")) if state else "—"


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        return 2
    key, issuer, kid, bundle = sys.argv[1:5]
    code, body = api_get(key, issuer, kid, "/v1/apps?filter[bundleId]=%s&limit=1" % bundle)
    if code != 200 or not body or not body.get("data"):
        print("Приложение %s не найдено (HTTP %d)" % (bundle, code))
        return 1
    app = body["data"][0]
    app_id = app["id"]
    print("Приложение: %s" % app["attributes"].get("name", bundle))

    code, body = api_get(key, issuer, kid, "/v1/apps/%s/appStoreVersions?limit=5" % app_id)
    print("\nВерсии (HTTP %d):" % code)
    for v in (body or {}).get("data", []):
        a = v["attributes"]
        print("  %s — %s; создана %s" % (a.get("versionString"), ru(a.get("appVersionState") or a.get("appStoreState")),
                                         (a.get("createdDate") or "")[:16]))

    code, body = api_get(key, issuer, kid, "/v1/reviewSubmissions?filter[app]=%s&limit=10" % app_id)
    print("\nОтправки на проверку (HTTP %d):" % code)
    subs = (body or {}).get("data", [])
    if not subs:
        print("  нет")
    for s in subs:
        a = s["attributes"]
        print("  %s — %s; отправлено %s" % (s["id"][:8], ru(a.get("state")), (a.get("submittedDate") or "—")[:16]))
        c2, items = api_get(key, issuer, kid, "/v1/reviewSubmissions/%s/items?include=appStoreVersion" % s["id"])
        versions = {inc["id"]: inc["attributes"].get("versionString")
                    for inc in (items or {}).get("included", []) if inc.get("type") == "appStoreVersions"}
        for it in (items or {}).get("data", []):
            rel = it.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}
            print("      элемент: версия %s — %s" % (versions.get(rel.get("id"), "?"), ru(it["attributes"].get("state"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
