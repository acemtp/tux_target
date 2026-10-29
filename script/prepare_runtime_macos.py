from pathlib import Path

root = Path(__file__).resolve().parents[1]
run = root / 'runtime-macos'
run.mkdir(exist_ok=True)
for directory in ('user_texture', 'replay'):
    (run / directory).mkdir(exist_ok=True)
if not (run / 'data').exists():
    (run / 'data').symlink_to(root / 'server/data', target_is_directory=True)
config = run / 'mtp_target_service.cfg'
if not config.exists():
    text = (root / 'server/mtp_target_service_default.cfg').read_text()
    text = text.replace('UserTexture   \t\t= "../user_texture";', 'UserTexture = "user_texture";')
    text = text.replace('ForcedClientCount    = 5;', 'ForcedClientCount    = 0;')
    text = text.replace('StartCommands        = { "watch 1" };', 'StartCommands        = { };')
    config.write_text(text)
