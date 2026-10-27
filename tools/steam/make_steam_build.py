#!/usr/bin/env python3
"""Windows + Linux builds for Steam, and the SteamPipe scripts that upload them.

  python3 tools/steam/make_steam_build.py --godot godot [--app 1234560 --win-depot 1234561 --linux-depot 1234562]

1. Exports the "Windows Desktop" and "Linux" presets (release) into build/windows/ and
   build/linux/ (TrestleRun.exe / TrestleRun.x86_64 plus TrestleRun.pck).
2. Zips each one into build/TrestleRun-<version>-windows.zip / -linux.zip, for trying
   the game on a PC or a Steam Deck outside Steam (the zip keeps the Linux file's
   executable bit).
3. With --app and the two depot ids (all three from Steamworks: App Admin > your app >
   SteamPipe > Depots), writes build/steam/app_build_<app>.vdf, the file SteamPipe's
   `steamcmd +run_app_build` uploads from. One depot per OS, each mapped to its folder.

The upload itself (your Steamworks login):
  steamcmd +login <steam user> +run_app_build "$PWD/build/steam/app_build_<app>.vdf" +quit
"""
import argparse
import os
import re
import subprocess
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BUILDS = [("Windows Desktop", "windows", "TrestleRun.exe"), ("Linux", "linux", "TrestleRun.x86_64")]


def version():
    with open(os.path.join(ROOT, "project.godot")) as f:
        m = re.search(r'^config/version="([^"]+)"', f.read(), re.M)
    return m.group(1) if m else "dev"


def export(godot):
    for preset, folder, exe in BUILDS:
        out = os.path.join(ROOT, "build", folder)
        os.makedirs(out, exist_ok=True)
        for f in os.listdir(out):
            os.remove(os.path.join(out, f))
        print("exporting", preset)
        r = subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", preset,
                            os.path.join(out, exe)], capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(os.path.join(out, exe)):
            print(r.stdout[-2000:], r.stderr[-2000:])
            sys.exit("export failed: " + preset)


def zip_builds():
    v = version()
    for _, folder, exe in BUILDS:
        src = os.path.join(ROOT, "build", folder)
        dst = os.path.join(ROOT, "build", "TrestleRun-%s-%s.zip" % (v, folder))
        with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
            for f in sorted(os.listdir(src)):
                info = zipfile.ZipInfo("TrestleRun/" + f, date_time=time.localtime()[:6])
                info.compress_type = zipfile.ZIP_DEFLATED
                mode = 0o755 if f == exe else 0o644
                info.external_attr = (0o100000 | mode) << 16  # regular file + permissions
                with open(os.path.join(src, f), "rb") as fh:
                    z.writestr(info, fh.read())
        print("wrote", dst, os.path.getsize(dst), "bytes")


VDF = """"AppBuild"
{
	"AppID" "%(app)s"
	"Desc" "Trestle Run %(version)s"
	"ContentRoot" "%(root)s"
	"BuildOutput" "%(output)s"
	"Depots"
	{
		"%(win)s"
		{
			"FileMapping"
			{
				"LocalPath" "windows/*"
				"DepotPath" "."
				"recursive" "1"
			}
		}
		"%(linux)s"
		{
			"FileMapping"
			{
				"LocalPath" "linux/*"
				"DepotPath" "."
				"recursive" "1"
			}
		}
	}
}
"""


def write_vdf(app, win, linux):
    steam = os.path.join(ROOT, "build", "steam")
    os.makedirs(steam, exist_ok=True)
    path = os.path.join(steam, "app_build_%s.vdf" % app)
    with open(path, "w") as f:
        f.write(VDF % {"app": app, "version": version(), "win": win, "linux": linux,
                       "root": os.path.join(ROOT, "build") + "/",
                       "output": os.path.join(steam, "output") + "/"})
    print("wrote", path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--no-export", action="store_true", help="reuse what's in build/windows and build/linux")
    ap.add_argument("--app", help="Steam App ID")
    ap.add_argument("--win-depot", help="Windows depot ID")
    ap.add_argument("--linux-depot", help="Linux depot ID")
    a = ap.parse_args()
    if not a.no_export:
        export(a.godot)
    zip_builds()
    if a.app:
        if not (a.win_depot and a.linux_depot):
            sys.exit("--app needs --win-depot and --linux-depot too")
        write_vdf(a.app, a.win_depot, a.linux_depot)


if __name__ == "__main__":
    main()
