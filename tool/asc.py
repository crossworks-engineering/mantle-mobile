#!/usr/bin/env python3
"""App Store Connect helper — the iOS twin of tool/play.py. Zero
third-party dependencies: the ES256 JWT is signed with the system
`openssl`, everything else is urllib.

Secrets: the .p8 key lives OUTSIDE the repo at
~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8. This script never
prints key material.

    tool/asc.py app                          app record, categories, versions,
                                             listing text per locale
    tool/asc.py listing set FILE.json        set the listing text (see
        [--locale en-US]                     store/appstore/listing.json)
    tool/asc.py screenshots DIR              replace the screenshots of one
        --display APP_IPHONE_67              display type from DIR/*.png
        [--locale en-US]
    tool/asc.py review set FILE.json         App Review contact + demo account
    tool/asc.py builds                       recent builds + processing state
    tool/asc.py build attach [N]             attach build number N (default: the
                                             newest VALID one) to the version
    tool/asc.py age-rating set FILE.json     answer the age rating questionnaire
    tool/asc.py rights none                  declare: no third-party content
    tool/asc.py pricing free                 base price USD 0 (all territories)
    tool/asc.py availability all             sell in every territory, new ones too

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_APP_ID override the defaults below.
"""

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
KEY_ID = os.environ.get("ASC_KEY_ID", "GWJK39ACCY")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "6fc9569f-d6a6-4a62-a93f-c18ddce71518")
APP_ID = os.environ.get("ASC_APP_ID", "6812760509")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _der_to_raw(der: bytes) -> bytes:
    """ECDSA DER SEQUENCE{INTEGER r, INTEGER s} -> raw r||s (32+32 bytes)."""
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert der[i] == 0x02
        n = der[i + 1]
        v = der[i + 2:i + 2 + n].lstrip(b"\x00")
        out += v.rjust(32, b"\x00")
        i += 2 + n
    return out


def token() -> str:
    if not os.path.exists(KEY_PATH):
        sys.exit(f"asc.py: no key at {KEY_PATH}")
    now = int(time.time())
    header = _b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    claims = _b64(json.dumps({"iss": ISSUER_ID, "iat": now, "exp": now + 1200,
                              "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{claims}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=signing_input, capture_output=True, check=True).stdout
    return f"{header}.{claims}.{_b64(_der_to_raw(der))}"


class ASC:
    def __init__(self):
        self.token = token()

    def call(self, method: str, path: str, body=None, params=None):
        url = path if path.startswith("http") else f"{API}{path}"
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.token}")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req) as r:
                text = r.read()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as e:
            sys.exit(f"asc.py: {method} {url}\n  HTTP {e.code}: {e.read().decode(errors='replace')}")

    def get(self, path, **params):
        return self.call("GET", path, params=params or None)

    def patch(self, path, type_, id_, attributes):
        return self.call("PATCH", path, body={"data": {"type": type_, "id": id_,
                                                       "attributes": attributes}})

    def post(self, type_, attributes, relationships=None):
        d = {"type": type_, "attributes": attributes}
        if relationships:
            d["relationships"] = relationships
        return self.call("POST", f"/{type_}", body={"data": d})


def _rel(type_, id_):
    return {"data": {"type": type_, "id": id_}}


# --- app --------------------------------------------------------------
def cmd_app(asc: ASC, _args):
    app = asc.get(f"/apps/{APP_ID}")["data"]["attributes"]
    print(f"app {APP_ID}: {app['name']}  bundle {app['bundleId']}  sku {app.get('sku')}  "
          f"primaryLocale {app.get('primaryLocale')}")

    for info in asc.get(f"/apps/{APP_ID}/appInfos", include="primaryCategory,secondaryCategory")["data"]:
        a = info["attributes"]
        rel = info["relationships"]
        cats = [rel.get(k, {}).get("data") or {} for k in ("primaryCategory", "secondaryCategory")]
        print(f"\nappInfo {info['id']}: state {a.get('appStoreState')}  "
              f"categories {[c.get('id') for c in cats]}")
        for loc in asc.get(f"/appInfos/{info['id']}/appInfoLocalizations")["data"]:
            la = loc["attributes"]
            print(f"  [{la['locale']}] name={la.get('name')!r} subtitle={la.get('subtitle')!r} "
                  f"privacy={la.get('privacyPolicyUrl')!r}")

    for v in asc.get(f"/apps/{APP_ID}/appStoreVersions", **{"filter[platform]": "IOS"})["data"]:
        va = v["attributes"]
        print(f"\nversion {v['id']}: {va['versionString']}  state {va['appStoreState']}  "
              f"release {va.get('releaseType')}")
        for loc in asc.get(f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]:
            la = loc["attributes"]
            desc = (la.get("description") or "")
            print(f"  [{la['locale']}] desc={len(desc)} chars keywords={la.get('keywords')!r} "
                  f"support={la.get('supportUrl')!r} marketing={la.get('marketingUrl')!r} "
                  f"promo={la.get('promotionalText')!r}")
            sets = asc.get(f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets",
                           include="appScreenshots")["data"]
            for s in sets:
                n = len(s["relationships"]["appScreenshots"]["data"])
                print(f"      screenshots {s['attributes']['screenshotDisplayType']}: {n}")
        rd = asc.get(f"/appStoreVersions/{v['id']}/appStoreReviewDetail").get("data")
        if rd:
            ra = rd["attributes"]
            print(f"  review: contact {ra.get('contactFirstName')} {ra.get('contactLastName')} "
                  f"<{ra.get('contactEmail')}> demo={ra.get('demoAccountRequired')} "
                  f"user={ra.get('demoAccountName')!r}")


# --- listing ----------------------------------------------------------
INFO_FIELDS = ("name", "subtitle", "privacyPolicyUrl", "privacyChoicesUrl")
VERSION_FIELDS = ("description", "keywords", "supportUrl", "marketingUrl",
                  "promotionalText", "whatsNew")


def _find_locale(items, locale):
    return next((i for i in items if i["attributes"]["locale"] == locale), None)


def cmd_listing(asc: ASC, args):
    with open(args.file) as f:
        text = json.load(f)
    info = asc.get(f"/apps/{APP_ID}/appInfos")["data"][0]
    loc = _find_locale(asc.get(f"/appInfos/{info['id']}/appInfoLocalizations")["data"], args.locale)
    if loc is None:
        sys.exit(f"asc.py: no appInfo localization for {args.locale}")
    attrs = {k: text[k] for k in INFO_FIELDS if k in text}
    if attrs:
        asc.patch(f"/appInfoLocalizations/{loc['id']}", "appInfoLocalizations", loc["id"], attrs)
        print(f"appInfo [{args.locale}] set: {', '.join(attrs)}")
    if "primaryCategory" in text:
        asc.call("PATCH", f"/appInfos/{info['id']}", body={"data": {
            "type": "appInfos", "id": info["id"],
            "relationships": {"primaryCategory": _rel("appCategories", text["primaryCategory"])}}})
        print(f"primaryCategory set: {text['primaryCategory']}")

    version = asc.get(f"/apps/{APP_ID}/appStoreVersions",
                      **{"filter[platform]": "IOS", "limit": 1})["data"][0]
    if text.get("versionString") and text["versionString"] != version["attributes"]["versionString"]:
        asc.patch(f"/appStoreVersions/{version['id']}", "appStoreVersions", version["id"],
                  {"versionString": text["versionString"]})
        print(f"versionString {version['attributes']['versionString']} -> {text['versionString']}")
        version["attributes"]["versionString"] = text["versionString"]
    vloc = _find_locale(asc.get(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"],
                        args.locale)
    if vloc is None:
        sys.exit(f"asc.py: no version localization for {args.locale}")
    attrs = {k: text[k] for k in VERSION_FIELDS if k in text}
    if attrs:
        asc.patch(f"/appStoreVersionLocalizations/{vloc['id']}", "appStoreVersionLocalizations",
                  vloc["id"], attrs)
        print(f"version {version['attributes']['versionString']} [{args.locale}] set: {', '.join(attrs)}")


# --- screenshots ------------------------------------------------------
def _upload(asc: ASC, reservation: dict, path: str):
    """Reserve → PUT each chunk → commit with the md5."""
    ops = reservation["attributes"]["uploadOperations"]
    with open(path, "rb") as f:
        raw = f.read()
    for op in ops:
        chunk = raw[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        with urllib.request.urlopen(req) as r:
            r.read()
    return hashlib.md5(raw).hexdigest()


def cmd_screenshots(asc: ASC, args):
    files = sorted(f for f in os.listdir(args.dir) if f.lower().endswith(".png"))
    if not files:
        sys.exit(f"asc.py: no .png in {args.dir}")
    version = asc.get(f"/apps/{APP_ID}/appStoreVersions",
                      **{"filter[platform]": "IOS", "limit": 1})["data"][0]
    vloc = _find_locale(asc.get(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"],
                        args.locale)
    sets = asc.get(f"/appStoreVersionLocalizations/{vloc['id']}/appScreenshotSets")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == args.display), None)
    if sset is None:
        sset = asc.post("appScreenshotSets", {"screenshotDisplayType": args.display},
                        {"appStoreVersionLocalization": _rel("appStoreVersionLocalizations", vloc["id"])})["data"]
        print(f"created set {args.display}")
    else:
        for old in asc.get(f"/appScreenshotSets/{sset['id']}/appScreenshots")["data"]:
            asc.call("DELETE", f"/appScreenshots/{old['id']}")
        print(f"cleared set {args.display}")
    for f in files:
        path = os.path.join(args.dir, f)
        res = asc.post("appScreenshots", {"fileName": f, "fileSize": os.path.getsize(path)},
                       {"appScreenshotSet": _rel("appScreenshotSets", sset["id"])})["data"]
        md5 = _upload(asc, res, path)
        asc.patch(f"/appScreenshots/{res['id']}", "appScreenshots", res["id"],
                  {"uploaded": True, "sourceFileChecksum": md5})
        print(f"  {f} -> {res['id']}")
    print("done (Apple processes them in the background)")


# --- review info ------------------------------------------------------
def cmd_review(asc: ASC, args):
    with open(args.file) as f:
        attrs = json.load(f)
    version = asc.get(f"/apps/{APP_ID}/appStoreVersions",
                      **{"filter[platform]": "IOS", "limit": 1})["data"][0]
    rd = asc.get(f"/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    if rd:
        asc.patch(f"/appStoreReviewDetails/{rd['id']}", "appStoreReviewDetails", rd["id"], attrs)
        print("review detail updated")
    else:
        asc.post("appStoreReviewDetails", attrs,
                 {"appStoreVersion": _rel("appStoreVersions", version["id"])})
        print("review detail created")


# --- builds -----------------------------------------------------------
def cmd_builds(asc: ASC, _args):
    for b in asc.get("/builds", **{"filter[app]": APP_ID, "sort": "-uploadedDate", "limit": 10})["data"]:
        a = b["attributes"]
        print(f"{b['id']}  {a['version']:>4}  {a['processingState']:10}  expired={a['expired']}  "
              f"{a['uploadedDate']}")


def _version(asc: ASC):
    return asc.get(f"/apps/{APP_ID}/appStoreVersions",
                   **{"filter[platform]": "IOS", "limit": 1})["data"][0]


def cmd_build(asc: ASC, args):
    builds = asc.get("/builds", **{"filter[app]": APP_ID, "sort": "-uploadedDate", "limit": 20})["data"]
    pick = next((b for b in builds if b["attributes"]["processingState"] == "VALID"
                 and (args.number is None or b["attributes"]["version"] == args.number)), None)
    if pick is None:
        sys.exit(f"asc.py: no VALID build {args.number or ''}".rstrip())
    v = _version(asc)
    asc.call("PATCH", f"/appStoreVersions/{v['id']}/relationships/build",
             body={"data": {"type": "builds", "id": pick["id"]}})
    print(f"build {pick['attributes']['version']} attached to version {v['attributes']['versionString']}")


def cmd_age_rating(asc: ASC, args):
    with open(args.file) as f:
        attrs = json.load(f)
    info = asc.get(f"/apps/{APP_ID}/appInfos")["data"][0]
    decl = asc.get(f"/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    asc.patch(f"/ageRatingDeclarations/{decl['id']}", "ageRatingDeclarations", decl["id"], attrs)
    print(f"age rating set ({len(attrs)} answers)")


def cmd_rights(asc: ASC, _args):
    asc.patch(f"/apps/{APP_ID}", "apps", APP_ID,
              {"contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"})
    print("contentRightsDeclaration: DOES_NOT_USE_THIRD_PARTY_CONTENT")


def cmd_pricing(asc: ASC, _args):
    points = asc.get(f"/apps/{APP_ID}/appPricePoints",
                     **{"filter[territory]": "USA", "limit": 50})["data"]
    free = next((p for p in points if float(p["attributes"]["customerPrice"]) == 0.0), None)
    if free is None:
        sys.exit("asc.py: no free price point found for USA")
    asc.call("POST", "/appPriceSchedules", body={
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": _rel("apps", APP_ID),
            "baseTerritory": _rel("territories", "USA"),
            "manualPrices": {"data": [{"type": "appPrices", "id": "${p0}"}]}}},
        "included": [{"type": "appPrices", "id": "${p0}",
                      "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": _rel("appPricePoints", free["id"])}}]})
    print("price schedule: free, base territory USA")


def cmd_availability(asc: ASC, _args):
    terrs, url = [], "/territories?limit=200"
    while url:
        page = asc.get(url)
        terrs += [t["id"] for t in page["data"]]
        url = page.get("links", {}).get("next")
    inc = [{"type": "territoryAvailabilities", "id": "${t%d}" % i,
            "attributes": {"available": True},
            "relationships": {"territory": _rel("territories", t)}} for i, t in enumerate(terrs)]
    asc.call("POST", "https://api.appstoreconnect.apple.com/v2/appAvailabilities", body={
        "data": {"type": "appAvailabilities",
                 "attributes": {"availableInNewTerritories": True},
                 "relationships": {"app": _rel("apps", APP_ID),
                                   "territoryAvailabilities": {"data": [
                                       {"type": "territoryAvailabilities", "id": x["id"]} for x in inc]}}},
        "included": inc})
    print(f"available in {len(terrs)} territories, new territories included")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("app")
    li = sub.add_parser("listing"); li.add_argument("action", choices=["set"])
    li.add_argument("file"); li.add_argument("--locale", default="en-US")
    sc = sub.add_parser("screenshots"); sc.add_argument("dir")
    sc.add_argument("--display", default="APP_IPHONE_67"); sc.add_argument("--locale", default="en-US")
    rv = sub.add_parser("review"); rv.add_argument("action", choices=["set"]); rv.add_argument("file")
    sub.add_parser("builds")
    bd = sub.add_parser("build"); bd.add_argument("action", choices=["attach"])
    bd.add_argument("number", nargs="?")
    ag = sub.add_parser("age-rating"); ag.add_argument("action", choices=["set"]); ag.add_argument("file")
    rt = sub.add_parser("rights"); rt.add_argument("action", choices=["none"])
    pr = sub.add_parser("pricing"); pr.add_argument("action", choices=["free"])
    av = sub.add_parser("availability"); av.add_argument("action", choices=["all"])
    args = p.parse_args()
    asc = ASC()
    {"app": cmd_app, "listing": cmd_listing, "screenshots": cmd_screenshots,
     "review": cmd_review, "builds": cmd_builds, "build": cmd_build,
     "age-rating": cmd_age_rating, "rights": cmd_rights, "pricing": cmd_pricing,
     "availability": cmd_availability}[args.cmd](asc, args)


if __name__ == "__main__":
    main()
