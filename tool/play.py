#!/usr/bin/env python3
"""Google Play release helper — the Android twin of the App Store Connect
helper. Zero third-party dependencies: the service-account JWT is signed
with the system `openssl`, everything else is urllib.

Secrets: the service-account JSON lives OUTSIDE the repo, by default at
~/.googleplay/service-account.json (override with $GOOGLE_PLAY_KEY). This
script never prints key material.

    tool/play.py tracks                       list tracks + their releases
    tool/play.py upload BUNDLE.aab            upload to the internal track
        [--track internal|alpha|beta|production] [--notes "text"]
        [--draft]                             leave the release as a draft
    tool/play.py promote --from internal --to beta   move the newest release
        [--notes "text"] [--draft]
    tool/play.py listings                     store-listing languages + titles
    tool/play.py listing get [--lang en-US]   show the listing text
    tool/play.py listing set DIR/listing.json set title / short / full description
    tool/play.py images DIR                   replace the listing graphics from
        [--lang en-US]                        DIR: icon-512.png, feature-*.png,
                                              phone-*.png (sorted order)

Package defaults to crossworks.engineering.jackdaw ($PLAY_PACKAGE).
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD_API = (
    "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
)
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
DEFAULT_PACKAGE = "crossworks.engineering.jackdaw"
DEFAULT_KEY = os.path.expanduser("~/.googleplay/service-account.json")


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def load_key() -> dict:
    path = os.environ.get("GOOGLE_PLAY_KEY", DEFAULT_KEY)
    try:
        with open(path) as f:
            key = json.load(f)
    except FileNotFoundError:
        sys.exit(f"play.py: no service-account key at {path} "
                 "(set $GOOGLE_PLAY_KEY or put it at the default path)")
    if key.get("type") != "service_account":
        sys.exit(f"play.py: {path} is not a service-account key")
    return key


def access_token(key: dict) -> str:
    """Sign a JWT with openssl (key fed on stdin, never written to disk)
    and swap it for a one-hour OAuth token."""
    now = int(time.time())
    header = _b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = _b64(json.dumps({
        "iss": key["client_email"],
        "scope": SCOPE,
        "aud": key["token_uri"],
        "iat": now,
        "exp": now + 3600,
    }).encode())
    signing_input = f"{header}.{claims}".encode()
    with tempfile.NamedTemporaryFile() as data:
        data.write(signing_input)
        data.flush()
        sig = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", "/dev/stdin", data.name],
            input=key["private_key"].encode(),
            capture_output=True,
            check=True,
        ).stdout
    jwt = f"{header}.{claims}.{_b64(sig)}"
    body = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": jwt,
    }).encode()
    req = urllib.request.Request(key["token_uri"], data=body, method="POST")
    with urllib.request.urlopen(req) as r:
        return json.load(r)["access_token"]


class Play:
    def __init__(self, package: str):
        self.package = package
        self.token = access_token(load_key())

    def _call(self, method: str, url: str, body=None, raw: bytes = None,
              content_type: str = "application/json"):
        data = raw if raw is not None else (
            json.dumps(body).encode() if body is not None else None)
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self.token}")
        if data is not None:
            req.add_header("Content-Type", content_type)
        try:
            with urllib.request.urlopen(req) as r:
                text = r.read()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")
            sys.exit(f"play.py: {method} {url}\n  HTTP {e.code}: {detail}")

    # --- edits -------------------------------------------------------
    def edit_open(self) -> str:
        return self._call("POST", f"{API}/{self.package}/edits")["id"]

    def edit_commit(self, edit: str):
        self._call("POST", f"{API}/{self.package}/edits/{edit}:commit")

    def edit_delete(self, edit: str):
        self._call("DELETE", f"{API}/{self.package}/edits/{edit}")

    def tracks(self, edit: str) -> list:
        return self._call("GET", f"{API}/{self.package}/edits/{edit}/tracks"
                          ).get("tracks", [])

    def upload_bundle(self, edit: str, path: str) -> int:
        with open(path, "rb") as f:
            raw = f.read()
        url = (f"{UPLOAD_API}/{self.package}/edits/{edit}/bundles"
               "?uploadType=media")
        return self._call("POST", url, raw=raw,
                          content_type="application/octet-stream")["versionCode"]

    def listings(self, edit: str) -> list:
        return self._call("GET", f"{API}/{self.package}/edits/{edit}/listings"
                          ).get("listings", [])

    def listing_get(self, edit: str, lang: str) -> dict:
        return self._call("GET", f"{API}/{self.package}/edits/{edit}/listings/{lang}")

    def listing_set(self, edit: str, lang: str, text: dict) -> dict:
        body = {"language": lang, **text}
        return self._call("PUT", f"{API}/{self.package}/edits/{edit}/listings/{lang}",
                          body=body)

    def images_delete_all(self, edit: str, lang: str, kind: str):
        self._call("DELETE", f"{API}/{self.package}/edits/{edit}/listings/{lang}/{kind}")

    def image_upload(self, edit: str, lang: str, kind: str, path: str) -> dict:
        with open(path, "rb") as f:
            raw = f.read()
        url = (f"{UPLOAD_API}/{self.package}/edits/{edit}/listings/{lang}/{kind}"
               "?uploadType=media")
        return self._call("POST", url, raw=raw, content_type="image/png")["image"]

    def set_track(self, edit: str, track: str, version_code: int,
                  status: str, notes: str | None):
        release = {"versionCodes": [str(version_code)], "status": status}
        if notes:
            release["releaseNotes"] = [{"language": "en-US", "text": notes}]
        return self._call("PUT", f"{API}/{self.package}/edits/{edit}/tracks/{track}",
                          body={"track": track, "releases": [release]})


# --- commands ----------------------------------------------------------
def cmd_tracks(play: Play, _args):
    edit = play.edit_open()
    try:
        tracks = play.tracks(edit)
    finally:
        play.edit_delete(edit)
    if not tracks:
        print("no tracks yet (upload the first bundle in the Play Console)")
        return
    for t in tracks:
        print(t["track"])
        for r in t.get("releases", []):
            codes = ",".join(r.get("versionCodes", [])) or "-"
            print(f"  {r.get('status','?'):10} {r.get('name','')}  "
                  f"versionCodes={codes}")


def cmd_upload(play: Play, args):
    if not os.path.isfile(args.bundle):
        sys.exit(f"play.py: no such file {args.bundle}")
    status = "draft" if args.draft else "completed"
    edit = play.edit_open()
    print(f"edit {edit}: uploading {os.path.basename(args.bundle)} "
          f"({os.path.getsize(args.bundle)//1_000_000} MB) ...")
    vc = play.upload_bundle(edit, args.bundle)
    print(f"  versionCode {vc}")
    play.set_track(edit, args.track, vc, status, args.notes)
    print(f"  track {args.track} <- {vc} ({status})")
    play.edit_commit(edit)
    print("committed")


def cmd_promote(play: Play, args):
    status = "draft" if args.draft else "completed"
    edit = play.edit_open()
    src = next((t for t in play.tracks(edit) if t["track"] == args.src), None)
    if not src or not src.get("releases"):
        play.edit_delete(edit)
        sys.exit(f"play.py: no release on track {args.src}")
    codes = src["releases"][0].get("versionCodes", [])
    if not codes:
        play.edit_delete(edit)
        sys.exit(f"play.py: newest release on {args.src} has no versionCode")
    vc = int(codes[0])
    play.set_track(edit, args.dst, vc, status, args.notes)
    play.edit_commit(edit)
    print(f"track {args.dst} <- {vc} ({status}) from {args.src}")


def cmd_listings(play: Play, _args):
    edit = play.edit_open()
    try:
        listings = play.listings(edit)
    finally:
        play.edit_delete(edit)
    if not listings:
        print("no store listings yet (create the default one in the Play Console)")
        return
    for l in listings:
        print(f"{l['language']:8} {l.get('title','')}")


def cmd_listing(play: Play, args):
    edit = play.edit_open()
    if args.action == "get":
        try:
            l = play.listing_get(edit, args.lang)
        finally:
            play.edit_delete(edit)
        for k in ("title", "shortDescription", "fullDescription", "video"):
            v = l.get(k, "")
            print(f"--- {k} ({len(v)} chars)\n{v}\n")
        return
    with open(args.file) as f:
        text = json.load(f)
    keep = {k: text[k] for k in ("title", "shortDescription", "fullDescription", "video")
            if k in text}
    play.listing_set(edit, args.lang, keep)
    play.edit_commit(edit)
    print(f"listing {args.lang} set: " + ", ".join(f"{k}={len(v)}" for k, v in keep.items()))
    print("committed")


IMAGE_KINDS = (  # Play imageType, file glob prefix
    ("icon", "icon-"),
    ("featureGraphic", "feature-"),
    ("phoneScreenshots", "phone-"),
)


def cmd_images(play: Play, args):
    if not os.path.isdir(args.dir):
        sys.exit(f"play.py: no such directory {args.dir}")
    edit = play.edit_open()
    for kind, prefix in IMAGE_KINDS:
        files = sorted(f for f in os.listdir(args.dir)
                       if f.startswith(prefix) and f.endswith(".png"))
        if not files:
            print(f"{kind}: no {prefix}*.png in {args.dir}, left as is")
            continue
        play.images_delete_all(edit, args.lang, kind)
        for f in files:
            img = play.image_upload(edit, args.lang, kind, os.path.join(args.dir, f))
            print(f"{kind}: {f} -> {img.get('id','?')}")
    play.edit_commit(edit)
    print("committed")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--package", default=os.environ.get("PLAY_PACKAGE", DEFAULT_PACKAGE))
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("tracks", help="list tracks and their releases")

    up = sub.add_parser("upload", help="upload a bundle and put it on a track")
    up.add_argument("bundle")
    up.add_argument("--track", default="internal")
    up.add_argument("--notes")
    up.add_argument("--draft", action="store_true")

    pr = sub.add_parser("promote", help="copy the newest release to another track")
    pr.add_argument("--from", dest="src", default="internal")
    pr.add_argument("--to", dest="dst", required=True)
    pr.add_argument("--notes")
    pr.add_argument("--draft", action="store_true")

    sub.add_parser("listings", help="list store-listing languages")

    li = sub.add_parser("listing", help="get or set the listing text")
    li.add_argument("action", choices=["get", "set"])
    li.add_argument("file", nargs="?", help="listing.json for set")
    li.add_argument("--lang", default="en-US")

    im = sub.add_parser("images", help="replace the listing graphics from a directory")
    im.add_argument("dir")
    im.add_argument("--lang", default="en-US")

    args = p.parse_args()
    play = Play(args.package)
    {"tracks": cmd_tracks, "upload": cmd_upload, "promote": cmd_promote,
     "listings": cmd_listings, "images": cmd_images,
     "listing": cmd_listing}[args.cmd](play, args)


if __name__ == "__main__":
    main()
