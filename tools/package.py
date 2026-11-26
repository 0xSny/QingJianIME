import datetime
import json
import os
import pathlib
import plistlib
import shutil
import struct
import subprocess
import zlib

root=pathlib.Path("build/Payload")
app=root/"QingJian.app"
ext=app/"PlugIns/Keyboard.appex"
version=os.environ["VERSION"]
build=os.environ["BUILD"]
for target,identifier,kind in [(app,"com.custom.ime","APPL"),(ext,"com.custom.ime.keyboard","XPC!")]:
    info=target/"Info.plist"
    subprocess.run(["plutil","-lint",info],check=True)
    pl=plistlib.loads(info.read_bytes())
    for k,v in dict(CFBundleIdentifier=identifier,CFBundlePackageType=kind,CFBundleVersion=build,CFBundleShortVersionString=version,MinimumOSVersion="16.0").items():
        assert pl[k]==v,(k,pl[k],v)
    subprocess.run(["lipo",target/pl["CFBundleExecutable"],"-verify_arch","arm64"],check=True)
    assert "$(" not in str(pl)
lex=(ext/"lex.bin").read_bytes()
assert lex[:4]==b"QJ17" and len(lex)>1000000 and struct.unpack_from("<II",lex,4)==(1,zlib.crc32(lex[40:]))
ipa=pathlib.Path("QingJian.ipa").resolve()
subprocess.run(["ditto","-c","-k","--keepParent","Payload",ipa],cwd="build",check=True)
repo=os.environ["GITHUB_REPOSITORY"]
site=pathlib.Path("site")
site.mkdir(exist_ok=True)
shutil.copy("Host/Assets.xcassets/AppIcon.appiconset/icon-1024.png",site/"icon.png")
url="https://github.com/"+repo+"/releases/download/v"+version+"/QingJian.ipa"
icon="https://"+repo.split("/")[0].lower()+".github.io/"+repo.split("/")[1]+"/icon.png"
date=datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
notes=subprocess.check_output(["git","log","-1","--format=%B"]).decode().strip()
item=dict(version=version,buildVersion=build,date=date,localizedDescription=notes,downloadURL=url,size=ipa.stat().st_size,minOSVersion="16.0")
app=dict(name="清简输入法",bundleIdentifier="com.custom.ime",developerName=repo.split("/")[0],localizedDescription="离线全拼与小鹤双拼键盘",iconURL=icon,tintColor="246568",versionDate=date,versionDescription=notes,version=version,downloadURL=url,size=item["size"],versions=[item])
(site/"source.json").write_text(json.dumps(dict(name="清简输入法",identifier="com.custom.ime.source",apps=[app]),ensure_ascii=False,indent=2))

