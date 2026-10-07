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
        [--rollout 0.1]                       staged: reach 10% of users first
    tool/play.py promote --from internal --to beta   copy the newest release
        [--version-code N] [--notes "text"]   (notes default: the source notes)
        [--draft | --rollout 0.1]             to another track
    tool/play.py rollout --track production   change a staged rollout:
        --fraction 0.5 | --complete |         new user fraction, go to 100%,
        --halt | --resume [--fraction F]      stop it, or start it again
    tool/play.py listings                     store-listing languages + titles
    tool/play.py listing get [--lang en-US]   show the listing text
    tool/play.py listing set DIR/listing.json set title / short / full description
    tool/play.py images DIR                   replace the listing graphics from
        [--lang en-US]                        DIR: icon-512.png, feature-*.png,
                                              phone-*.png (sorted order)

Every command takes --dry-run: the edit is opened and read, the change is
printed, and the edit is deleted. Nothing is uploaded or committed.

    tool/play.py --dry-run promote --from alpha --to production --rollout 0.1

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
    def __init__(self, package: str, dry_run: bool = False):
        self.package = package
        self.dry_run = dry_run
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

    def put_track(self, edit: str, track: str, releases: list):
        body = {"track": track, "releases": releases}
        if self.dry_run:
            print(f"[dry-run] PUT edits/<edit>/tracks/{track}")
            print("          " + json.dumps(body, ensure_ascii=False))
            return body
        return self._call("PUT", f"{API}/{self.package}/edits/{edit}/tracks/{track}",
                          body=body)

    def set_track(self, edit: str, track: str, version_code: int,
                  status: str, notes, user_fraction: float | None = None):
        """notes: a string (en-US) or a releaseNotes list copied from a track."""
        release = {"versionCodes": [str(version_code)], "status": status}
        if user_fraction is not None:
            release["userFraction"] = user_fraction
        if isinstance(notes, str) and notes:
            release["releaseNotes"] = [{"language": "en-US", "text": notes}]
        elif notes:
            release["releaseNotes"] = notes
        return self.put_track(edit, track, [release])

    def finish(self, edit: str):
        """Commit the edit, or (dry run) throw it away."""
        if self.dry_run:
            self.edit_delete(edit)
            print("[dry-run] edit deleted, nothing committed")
        else:
            self.edit_commit(edit)
            print("committed")


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


def _release_status(args) -> tuple[str, float | None]:
    """completed, draft, or inProgress with a userFraction (staged rollout)."""
    if args.rollout is None:
        return ("draft" if args.draft else "completed"), None
    if args.draft:
        sys.exit("play.py: --draft and --rollout do not go together")
    if not 0 < args.rollout < 1:
        sys.exit("play.py: --rollout is a fraction between 0 and 1, such as 0.1 for 10%")
    return "inProgress", args.rollout


def _show(status: str, fraction: float | None) -> str:
    return f"{status} {fraction:.0%}" if fraction is not None else status


def cmd_upload(play: Play, args):
    if not os.path.isfile(args.bundle):
        sys.exit(f"play.py: no such file {args.bundle}")
    status, fraction = _release_status(args)
    if play.dry_run:
        print(f"[dry-run] would upload {os.path.basename(args.bundle)} "
              f"({os.path.getsize(args.bundle)//1_000_000} MB) and set track "
              f"{args.track} <- <new versionCode> ({_show(status, fraction)})")
        return
    edit = play.edit_open()
    print(f"edit {edit}: uploading {os.path.basename(args.bundle)} "
          f"({os.path.getsize(args.bundle)//1_000_000} MB) ...")
    vc = play.upload_bundle(edit, args.bundle)
    print(f"  versionCode {vc}")
    play.set_track(edit, args.track, vc, status, args.notes, fraction)
    print(f"  track {args.track} <- {vc} ({_show(status, fraction)})")
    play.finish(edit)


def cmd_promote(play: Play, args):
    status, fraction = _release_status(args)
    edit = play.edit_open()
    src = next((t for t in play.tracks(edit) if t["track"] == args.src), None)
    releases = [r for r in (src or {}).get("releases", []) if r.get("versionCodes")]
    if args.version_code is not None:
        releases = [r for r in releases if str(args.version_code) in r["versionCodes"]]
    if not releases:
        play.edit_delete(edit)
        sys.exit(f"play.py: no release on track {args.src}"
                 + (f" with versionCode {args.version_code}" if args.version_code else ""))
    rel = max(releases, key=lambda r: max(int(c) for c in r["versionCodes"]))
    vc = args.version_code or max(int(c) for c in rel["versionCodes"])
    notes = args.notes or rel.get("releaseNotes")
    play.set_track(edit, args.dst, vc, status, notes, fraction)
    play.finish(edit)
    print(("[dry-run] would set " if play.dry_run else "") +
          f"track {args.dst} <- {vc} ({_show(status, fraction)}) from {args.src}")


def cmd_rollout(play: Play, args):
    actions = [a for a in ("complete", "halt", "resume") if getattr(args, a)]
    if len(actions) > 1 or (not actions and args.fraction is None):
        sys.exit("play.py: give one of --fraction F, --complete, --halt, --resume")
    if args.fraction is not None and not 0 < args.fraction < 1:
        sys.exit("play.py: --fraction is between 0 and 1, such as 0.5 for 50% "
                 "(use --complete for 100%)")
    if args.fraction is not None and actions in (["complete"], ["halt"]):
        sys.exit(f"play.py: --fraction does not go with --{actions[0]}")
    edit = play.edit_open()
    track = next((t for t in play.tracks(edit) if t["track"] == args.track), None)
    releases = (track or {}).get("releases", [])
    want = "halted" if args.resume else "inProgress"
    staged = next((r for r in releases if r.get("status") == want), None)
    if staged is None:
        play.edit_delete(edit)
        sys.exit(f"play.py: no {want} release on track {args.track}"
                 + (" (nothing to resume)" if args.resume else " (no staged rollout)"))
    codes = ",".join(staged["versionCodes"])
    before = _show(staged["status"], staged.get("userFraction"))
    if args.complete:
        staged = {k: v for k, v in staged.items() if k != "userFraction"}
        staged["status"] = "completed"
        new = [staged]  # the older completed release is replaced
    else:
        staged = dict(staged)
        if args.halt:
            staged["status"] = "halted"
        else:
            staged["status"] = "inProgress"
            if args.fraction is not None:
                if args.fraction <= staged.get("userFraction", 0) and not args.resume:
                    play.edit_delete(edit)
                    sys.exit(f"play.py: a rollout only goes up; it is at {before} now")
                staged["userFraction"] = args.fraction
        new = [staged if r.get("status") == want else r for r in releases]
    play.put_track(edit, args.track, new)
    play.finish(edit)
    print(("[dry-run] would set " if play.dry_run else "") +
          f"track {args.track} versionCode {codes}: {before} -> "
          f"{_show(staged['status'], staged.get('userFraction'))}")


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
    if play.dry_run:
        print(f"[dry-run] PUT edits/<edit>/listings/{args.lang}: "
              + ", ".join(f"{k}={len(v)} chars" for k, v in keep.items()))
    else:
        play.listing_set(edit, args.lang, keep)
    play.finish(edit)
    if not play.dry_run:
        print(f"listing {args.lang} set: " + ", ".join(f"{k}={len(v)}" for k, v in keep.items()))


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
        if play.dry_run:
            print(f"[dry-run] {kind}: replace with {', '.join(files)}")
            continue
        play.images_delete_all(edit, args.lang, kind)
        for f in files:
            img = play.image_upload(edit, args.lang, kind, os.path.join(args.dir, f))
            print(f"{kind}: {f} -> {img.get('id','?')}")
    play.finish(edit)


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter,
                                epilog=__doc__.split("\n\n", 1)[1])
    p.add_argument("--package", default=os.environ.get("PLAY_PACKAGE", DEFAULT_PACKAGE))
    p.add_argument("--dry-run", action="store_true",
                   help="open and read an edit, print the change, delete the edit")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("tracks", help="list tracks and their releases")

    up = sub.add_parser("upload", help="upload a bundle and put it on a track")
    up.add_argument("bundle")
    up.add_argument("--track", default="internal")
    up.add_argument("--notes")
    up.add_argument("--draft", action="store_true")
    up.add_argument("--rollout", type=float, metavar="F",
                    help="staged rollout: start at this user fraction (0.1 = 10%%)")

    pr = sub.add_parser("promote", help="copy the newest release to another track",
                        description="Copy a release from one track to another, for "
                        "example internal -> alpha, or alpha -> production with a staged "
                        "rollout. The release notes come from the source release unless "
                        "--notes is given. Production can refuse with FAILED_PRECONDITION "
                        "until Google grants production access.")
    pr.add_argument("--from", dest="src", default="internal",
                    help="source track (default internal)")
    pr.add_argument("--to", dest="dst", required=True,
                    help="target track: internal, alpha, beta or production")
    pr.add_argument("--version-code", type=int, metavar="N",
                    help="promote this versionCode (default: the newest on the source)")
    pr.add_argument("--notes", help="release notes (en-US); default: the source notes")
    pr.add_argument("--draft", action="store_true", help="leave the release as a draft")
    pr.add_argument("--rollout", type=float, metavar="F",
                    help="staged rollout: start at this user fraction (0.1 = 10%%)")

    ro = sub.add_parser("rollout", help="change a staged rollout",
                        description="Change the staged (inProgress) release on a track: "
                        "raise its user fraction, take it to 100% (--complete), stop it "
                        "(--halt), or start a halted one again (--resume, optionally with "
                        "a new --fraction). A fraction only goes up.")
    ro.add_argument("--track", default="production", help="track (default production)")
    ro.add_argument("--fraction", type=float, metavar="F",
                    help="new user fraction between 0 and 1, such as 0.5 for 50%%")
    ro.add_argument("--complete", action="store_true", help="release to all users")
    ro.add_argument("--halt", action="store_true", help="stop the rollout")
    ro.add_argument("--resume", action="store_true", help="start a halted rollout again")

    sub.add_parser("listings", help="list store-listing languages")

    li = sub.add_parser("listing", help="get or set the listing text")
    li.add_argument("action", choices=["get", "set"])
    li.add_argument("file", nargs="?", help="listing.json for set")
    li.add_argument("--lang", default="en-US")

    im = sub.add_parser("images", help="replace the listing graphics from a directory")
    im.add_argument("dir")
    im.add_argument("--lang", default="en-US")

    for sp in sub.choices.values():  # --dry-run also works after the command name
        sp.add_argument("--dry-run", action="store_true", default=argparse.SUPPRESS,
                        help="open and read an edit, print the change, delete the edit")
    args = p.parse_args()
    play = Play(args.package, dry_run=args.dry_run)
    if args.dry_run:
        print("[dry-run] nothing is uploaded or committed")
    {"tracks": cmd_tracks, "upload": cmd_upload, "promote": cmd_promote,
     "rollout": cmd_rollout,
     "listings": cmd_listings, "images": cmd_images,
     "listing": cmd_listing}[args.cmd](play, args)


if __name__ == "__main__":
    main()
