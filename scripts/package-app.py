from pathlib import Path
import plistlib
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
binary_dir = subprocess.check_output(['swift', 'build', '--package-path', str(root / 'native'), '-c', 'release', '--show-bin-path'], text=True).strip()
binary = Path(binary_dir) / 'CitrusNative'
if not binary.is_file():
    raise SystemExit('Build the release executable first.')
dist = root / 'dist'
app = dist / '橘子.app'
if app.exists():
    previous = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if previous.get('CFBundleIdentifier') != 'local.kris.citrus':
        raise SystemExit('Refusing to replace an unrelated app.')
    shutil.rmtree(app)
(app / 'Contents/MacOS').mkdir(parents=True)
resources = app / 'Contents/Resources'
resources.mkdir()
iconset = dist / 'Citrus.iconset'
iconset.mkdir(exist_ok=True)
icon_source = dist / 'Citrus.png'
subprocess.run(['/usr/bin/swift', str(root / 'assets/AppIcon.swift'), str(icon_source)], check=True)
for pixels in [16, 32, 128, 256, 512]:
    for retina in [False, True]:
        filename = f'icon_{pixels}x{pixels}' + ('@2x' if retina else '') + '.png'
        value = str(pixels * (2 if retina else 1))
        subprocess.run(['/usr/bin/sips', '-z', value, value, str(icon_source), '--out', str(iconset / filename)], check=True, stdout=subprocess.DEVNULL)
subprocess.run(['/usr/bin/iconutil', '-c', 'icns', str(iconset), '-o', str(resources / 'Citrus.icns')], check=True)
shutil.copy2(binary, app / 'Contents/MacOS/CitrusNative')
plist = {
    'CFBundleExecutable': 'CitrusNative', 'CFBundleIdentifier': 'local.kris.citrus',
    'CFBundleName': '橘子', 'CFBundleDisplayName': '橘子', 'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '1.1.0', 'CFBundleVersion': '3', 'LSMinimumSystemVersion': '14.0',
    'CFBundleIconFile': 'Citrus.icns', 'LSUIElement': True, 'NSHighResolutionCapable': True,
    'NSPrincipalClass': 'NSApplication',
    'CFBundleDocumentTypes': [{'CFBundleTypeName': 'Files', 'CFBundleTypeRole': 'Viewer',
        'LSItemContentTypes': ['public.image', 'com.adobe.pdf', 'public.audio', 'public.movie', 'public.plain-text', 'public.archive']}]
}
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(plist))
shutil.copytree(root / 'licenses', resources / 'Licenses')
shutil.copy2(root / 'LICENSE', resources / 'Licenses/Citrus-MIT.txt')
shutil.copy2(root / 'THIRD_PARTY_NOTICES.md', resources / 'THIRD_PARTY_NOTICES.md')
subprocess.run(['/usr/bin/codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print(app)
