from pathlib import Path
import shutil
import tempfile

repo = Path(__file__).resolve().parents[3]
checkout = Path(tempfile.mkdtemp(prefix='pippipgo-screenshots-', dir='/private/tmp'))
for name in ['pippipgo', 'pippipgo.xcodeproj', 'Configurations', 'Resources']:
    shutil.copytree(repo / name, checkout / name)
entry = checkout / 'pippipgo/App/pippipgoApp.swift'
text = entry.read_text()
start = text.index('            RootView(store: authenticationStore)')
end = text.index('\n        }', start)
text = text[:start] + '            ScreenshotGallery()' + text[end:]
entry.write_text(text + '\n' + Path(__file__).with_name('ScreenshotFixture.swift').read_text())
print(checkout)

# Allow fictional transcript injection only in this disposable capture checkout.
voice = checkout / 'pippipgo/Intelligence/LiveVoice.swift'
voice.write_text(voice.read_text().replace('private(set) var transcript', 'var transcript'))
