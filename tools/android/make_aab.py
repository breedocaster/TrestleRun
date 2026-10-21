#!/usr/bin/env python3
"""Android App Bundle (.aab) for Play Console from Godot's release APK, no Gradle.

Godot's Gradle build makes an .aab directly, but it needs the Android Gradle plugin
from Google's Maven, which this machine can't reach. A bundle is the APK's contents
rearranged (one "base" module) with the manifest, resource table and XML resources in
aapt2's protobuf format instead of binary XML, so this does it by hand:

  1. Copy the APK, adding res/mipmap-anydpi-v26/themed_icon.xml. Godot's exporter
     writes the themed icon into icon.xml and drops themed_icon.xml, but the resource
     table still lists it; an installed APK never notices, aapt2 and bundletool refuse.
  2. aapt2 convert --output-format proto: manifest, resources.arsc -> resources.pb
     and res/**.xml to protobuf; everything else is copied as it is.
  3. Lay the files out as a bundle module: manifest/, dex/, res/, assets/, lib/,
     resources.pb, root/ (everything else; the old signature files are dropped) and
     the baseline profile as bundle metadata, where the Android Gradle plugin puts it.
  4. bundletool build-bundle with a BundleConfig: native libraries uncompressed and
     16 KB page aligned where the device allows it (Play's 16 KB page rule), and every
     file Godot stored uncompressed in the APK kept uncompressed in Play's APKs.
  5. bundletool validate, then jarsigner with the upload key.

  python3 tools/android/make_aab.py --apk build/trestle-run-release.apk \\
      --out build/trestle-run.aab --keystore ~/keys/trestle-upload.jks --alias upload
  (the keystore password comes from $TRESTLE_UPLOAD_PASSWORD)

--verify also has bundletool build the APKs Play would serve (a universal APK, and
the split set for an arm64 Android 14 phone) and checks them against the source APK:
every dex, native library, asset and resource byte for byte, every XML file and the
resource table through aapt2's dumps, and the 16 KB alignment of the libraries.
"""
import argparse
import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SIG = re.compile(r"^META-INF/([^/]+\.(SF|RSA|DSA|EC)|MANIFEST\.MF)$", re.I)
PROFILES = {"assets/dexopt/baseline.prof": "baseline.prof",
            "assets/dexopt/baseline.profm": "baseline.profm"}
THEMED = "res/mipmap-anydpi-v26/themed_icon.xml"
ICON = "res/mipmap-anydpi-v26/icon.xml"


def run(cmd, **kw):
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=True, **kw)


def glob_escape(path):
    # Java PathMatcher glob syntax (what bundletool uses): escape its special characters.
    return re.sub(r"([\\*?\[\]{}])", r"\\\1", path)


def module_path(name):
    if name == "AndroidManifest.xml":
        return "manifest/AndroidManifest.xml"
    if name == "resources.pb":
        return "resources.pb"
    if re.fullmatch(r"classes\d*\.dex", name):
        return "dex/" + name
    if name.split("/")[0] in ("res", "assets", "lib"):
        return name
    return "root/" + name


def build(args, work):
    src = zipfile.ZipFile(args.apk)
    names = src.namelist()

    # 1. The themed icon file the resource table points at.
    fixed = os.path.join(work, "fixed.apk")
    with zipfile.ZipFile(fixed, "w", zipfile.ZIP_DEFLATED) as out:
        for info in src.infolist():
            # (a copy: writestr() rewrites the ZipInfo's offsets for the new file)
            out.writestr(copy.copy(info), src.read(info.filename))
        if THEMED not in names and ICON in names:
            out.writestr(THEMED, src.read(ICON))
            print("added", THEMED, "(a copy of", ICON + ")")

    # 2. Protobuf resources.
    proto = os.path.join(work, "proto.apk")
    run([args.aapt2, "convert", "--output-format", "proto", "-o", proto, fixed])

    # 3. The base module.
    base = os.path.join(work, "base.zip")
    meta = []
    stored = []
    pz = zipfile.ZipFile(proto)
    with zipfile.ZipFile(base, "w", zipfile.ZIP_DEFLATED) as out:
        for info in pz.infolist():
            n = info.filename
            if n.endswith("/") or SIG.match(n):
                continue
            if n in PROFILES:
                p = os.path.join(work, PROFILES[n])
                with open(p, "wb") as f:
                    f.write(pz.read(n))
                meta.append("com.android.tools.build.profiles/%s:%s" % (PROFILES[n], p))
                continue
            out.writestr(module_path(n), pz.read(n))
    for info in src.infolist():
        n = info.filename
        if (info.compress_type == zipfile.ZIP_STORED and not n.endswith("/")
                and not SIG.match(n) and n not in PROFILES and n != "resources.arsc"):
            stored.append(glob_escape(n))

    # 4. The bundle.
    config = {
        "optimizations": {
            "uncompressNativeLibraries": {"enabled": True, "alignment": "PAGE_ALIGNMENT_16K"},
        },
        "compression": {"uncompressedGlob": sorted(stored)},
    }
    cfg = os.path.join(work, "BundleConfig.json")
    with open(cfg, "w") as f:
        json.dump(config, f, indent=1)
    unsigned = os.path.join(work, "unsigned.aab")
    cmd = ["java", "-jar", args.bundletool, "build-bundle", "--modules=" + base,
           "--output=" + unsigned, "--config=" + cfg, "--overwrite"]
    cmd += ["--metadata-file=" + m for m in meta]
    run(cmd)
    run(["java", "-jar", args.bundletool, "validate", "--bundle=" + unsigned],
        stdout=subprocess.DEVNULL)

    # 5. Sign with the upload key.
    shutil.copyfile(unsigned, args.out)
    if args.keystore:
        pw = os.environ.get(args.password_env)
        if not pw:
            sys.exit("set $%s to the keystore password" % args.password_env)
        run(["jarsigner", "-keystore", args.keystore, "-storepass:env", args.password_env,
             "-sigalg", "SHA256withRSA", "-digestalg", "SHA-256", args.out, args.alias],
            stdout=subprocess.DEVNULL)
        run(["jarsigner", "-verify", "-strict", args.out, args.alias, "-keystore", args.keystore,
             "-storepass:env", args.password_env], stdout=subprocess.DEVNULL)
    print("wrote", args.out, os.path.getsize(args.out), "bytes")


# ---------------------------------------------------------------- verification

def dump(aapt2, what, apk, f=None):
    cmd = [aapt2, "dump", what] + (["--file", f] if f else []) + [apk]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout


# What bundletool adds to every APK it makes from a bundle: two <meta-data> tags naming
# the module and the split list, and that list (res/xml/splits0.xml).
ADDED_META = ("com.android.dynamic.apk.fused.modules", "com.android.vending.splits")


def strip_added_meta(dump_text):
    lines = dump_text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        if lines[i].strip() == "E: meta-data (line=0)" and i + 1 < len(lines) \
                and any(m in lines[i + 1] for m in ADDED_META):
            i += 3
            continue
        out.append(lines[i])
        i += 1
    return "\n".join(out)


def strip_added_res(dump_text):
    t = "\n".join(l for l in dump_text.split("\n") if "splits0" not in l)
    return re.sub(r"(type xml id=\w+ entryCount=)\d+", r"\1N", t)


def apk_entries(path):
    z = zipfile.ZipFile(path)
    return z, {i.filename: i for i in z.infolist() if not SIG.match(i.filename)}


def data_offset(path, info):
    with open(path, "rb") as f:
        f.seek(info.header_offset)
        h = f.read(30)
    return info.header_offset + 30 + int.from_bytes(h[26:28], "little") + int.from_bytes(h[28:30], "little")


def verify(args, work):
    bt = ["java", "-jar", args.bundletool]
    ok = True

    def bad(msg):
        nonlocal ok
        ok = False
        print("FAIL", msg)

    # The APK set Play would make for a device that takes everything: one universal APK.
    uni = os.path.join(work, "universal.apks")
    run(bt + ["build-apks", "--bundle=" + args.out, "--output=" + uni, "--mode=universal",
              "--overwrite"], stdout=subprocess.DEVNULL)
    zipfile.ZipFile(uni).extract("universal.apk", work)
    u_apk = os.path.join(work, "universal.apk")
    sz, s = apk_entries(args.apk)
    uz, u = apk_entries(u_apk)
    # Files the APK doesn't need checked here: the resource table and binary XML are
    # regenerated by bundletool (compared through aapt2 below); the profile moves.
    xml = [n for n in s if n == "AndroidManifest.xml" or (n.startswith("res/") and n.endswith(".xml"))]
    for n in s:
        if n in xml or n == "resources.arsc":
            continue
        if n not in u:
            bad("missing from universal APK: " + n)
        elif sz.read(n) != uz.read(n):
            bad("bytes differ: " + n)
        elif s[n].compress_type == zipfile.ZIP_STORED and u[n].compress_type != zipfile.ZIP_STORED \
                and not n.startswith("lib/"):
            bad("compressed but Godot stored it: " + n)
    extra = sorted(set(u) - set(s) - {THEMED, "res/xml/splits0.xml"})
    print("universal APK: %d files, %d checked byte for byte, %d XML; only in the bundle's APK: %s"
          % (len(u), len(s) - len(xml) - 1, len(xml), extra))
    for n in xml:
        a = dump(args.aapt2, "xmltree", args.apk, n)
        b = dump(args.aapt2, "xmltree", u_apk, n)
        if n == "AndroidManifest.xml":
            b = strip_added_meta(b)
        if not a or a != b:
            bad("XML differs: " + n)
    if THEMED not in s and dump(args.aapt2, "xmltree", u_apk, THEMED) != \
            dump(args.aapt2, "xmltree", args.apk, ICON):
        bad("themed icon isn't the icon.xml copy")
    ra = strip_added_res(dump(args.aapt2, "resources", args.apk))
    rb = strip_added_res(dump(args.aapt2, "resources", u_apk))
    if not ra or ra != rb:
        bad("resource table differs")
    if dump(args.aapt2, "badging", args.apk) != dump(args.aapt2, "badging", u_apk):
        bad("badging differs")

    # A real phone's split set: arm64, Android 14, xxhdpi, English.
    spec = os.path.join(work, "device.json")
    with open(spec, "w") as f:
        json.dump({"supportedAbis": ["arm64-v8a"], "supportedLocales": ["en-US"],
                   "screenDensity": 420, "sdkVersion": 34}, f)
    dev = os.path.join(work, "device.apks")
    run(bt + ["build-apks", "--bundle=" + args.out, "--output=" + dev, "--device-spec=" + spec,
              "--overwrite"], stdout=subprocess.DEVNULL)
    dz = zipfile.ZipFile(dev)
    splits = [n for n in dz.namelist() if n.endswith(".apk")]
    print("arm64 phone gets:", splits)
    libs = 0
    for n in splits:
        p = os.path.join(work, "dev_" + os.path.basename(n))
        with open(p, "wb") as f:
            f.write(dz.read(n))
        z = zipfile.ZipFile(p)
        for i in z.infolist():
            if i.filename.startswith("lib/") and i.filename.endswith(".so"):
                libs += 1
                off = data_offset(p, i)
                if i.compress_type != zipfile.ZIP_STORED or off % 16384:
                    bad("%s in %s: compress %d, offset %d" % (i.filename, n, i.compress_type, off))
                if z.read(i.filename) != sz.read(i.filename):
                    bad("library bytes differ: " + i.filename)
        if "base-master" in n:
            m = dump(args.aapt2, "xmltree", p, "AndroidManifest.xml")
            if "extractNativeLibs(0x010104ea)=false" not in m:
                bad("base split doesn't set extractNativeLibs=false")
            names = z.namelist()
            for prof in PROFILES:
                if prof not in names:
                    bad("baseline profile missing from base split: " + prof)
    if libs != sum(1 for n in s if n.startswith("lib/")):
        bad("expected %d native libraries in the splits, found %d" % (sum(1 for n in s if n.startswith("lib/")), libs))
    print("VERIFY", "OK" if ok else "FAILED")
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--apk", required=True, help="Godot's release APK")
    ap.add_argument("--out", required=True, help="the .aab to write")
    ap.add_argument("--aapt2", default=os.environ.get("AAPT2", "aapt2"))
    ap.add_argument("--bundletool", default=os.environ.get("BUNDLETOOL", "bundletool-all.jar"),
                    help="bundletool-all-<version>.jar")
    ap.add_argument("--keystore", help="upload keystore (unsigned bundle if left out)")
    ap.add_argument("--alias", default="upload")
    ap.add_argument("--password-env", default="TRESTLE_UPLOAD_PASSWORD",
                    help="environment variable holding the keystore password")
    ap.add_argument("--verify", action="store_true", help="check the bundle against the APK")
    ap.add_argument("--work", help="keep intermediate files here")
    args = ap.parse_args()
    work = args.work or tempfile.mkdtemp(prefix="aab_")
    os.makedirs(work, exist_ok=True)
    try:
        build(args, work)
        if args.verify and not verify(args, work):
            sys.exit(1)
    finally:
        if not args.work:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
