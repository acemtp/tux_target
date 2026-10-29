from pathlib import Path
import plistlib
import re
import shutil
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
runtime = root / 'runtime-macos-client'
runtime.mkdir(exist_ok=True)
for name in ('cache', 'replay', 'config', 'xdg-cache'):
    (runtime / name).mkdir(exist_ok=True)

# NeL needs logical sound sheets as well as the original WAVs. Reconstruct
# these from available assets; retain the upstream schemas in the local runtime.
audio = runtime / 'audio'
audio.mkdir(exist_ok=True)
schemas = root / '.deps/src/ryzomcore/nel/samples/sound/sound_sources/data/DFN'
shutil.copytree(schemas, audio / 'definitions', dirs_exist_ok=True)
effects = {'open': 'open.wav', 'close': 'close.wav', 'impact': 'impact.wav', 'ready': 'ready.wav'}
# Remove the earlier generated per-digit aliases: the WAV is a full countdown.
for index in range(6):
    (audio / f'ready{index}.sound').unlink(missing_ok=True)
if (root / 'client/data/sound/splash.wav').exists():
    effects['splash'] = 'splash.wav'
for name, filename in effects.items():
    form = ET.Element('FORM', {'Revision': '1', 'State': 'modified'})
    struct = ET.SubElement(form, 'STRUCT')
    sound_type = ET.SubElement(struct, 'VSTRUCT', {'DfnName': 'simple_sound.dfn', 'Name': 'SoundType'})
    for key, value in [('Filename', filename), ('MinDistance', '1.0'), ('MaxDistance', '100.0')]:
        ET.SubElement(sound_type, 'ATOM', {'Name': key, 'Value': value})
    ET.SubElement(struct, 'ATOM', {'Name': 'Loop', 'Value': 'false'})
    ET.SubElement(struct, 'ATOM', {'Name': 'Gain', 'Value': '0dB'})
    ET.SubElement(struct, 'ATOM', {'Name': 'GroupController', 'Value': 'sound'})
    ET.ElementTree(form).write(audio / f'{name}.sound', encoding='utf-8', xml_declaration=True)
config = runtime / 'tux-target.cfg'
if not config.exists():
    text = (root / 'client/tux-target.cfg.in').read_text()
    text = text.replace('@TUX_TARGET_DATA_DIR@', str(root / 'client/data'))
    # Both folders belong to this checkout; no dependency on tux_target.
    text = text.replace(f'Path = {{ "{root / "client/data"}" }};',
                        f'Path = {{ "{root / "client/data"}", "{root / "server/data"}" }};')
    text = re.sub(r'Fullscreen\s*=\s*1;', 'Fullscreen = 0;', text)
    text = re.sub(r'SoundDriver\s*=\s*"Auto";', 'SoundDriver = "OpenAL";', text)
    config.write_text(text)

# Migrate only the broken shipped playlist name; preserve custom playlists.
text = config.read_text()
text = re.sub(r'(M3UList\s*=\s*)"tux-target\.m3u"', r'\1"mtp-target.m3u"', text)
config.write_text(text)

contents = root / 'dist/Tux Target.app/Contents'
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'build-macos-client/tux-target', contents / 'MacOS/tux-target')
resources = contents / 'Resources'
if not resources.exists():
    resources.symlink_to(runtime, target_is_directory=True)
info = {
    'CFBundleExecutable': 'tux-target',
    'CFBundleIdentifier': 'org.tuxtarget.client.local',
    'CFBundleName': 'Tux Target',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '1.19.0',
    'CFBundleVersion': '1.19.0',
    'NSHighResolutionCapable': False,
    'NSPrincipalClass': 'NSApplication',
}
with (contents / 'Info.plist').open('wb') as stream:
    plistlib.dump(info, stream)
