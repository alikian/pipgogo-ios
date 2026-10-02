from pathlib import Path
import subprocess
import time
import sys

build = Path(sys.argv[1])
device = sys.argv[2]
bundle = 'com.pippipgo.screenshots'
out = Path(__file__).resolve().parent.parent / 'screenshots' / 'iphone-6.9'
out.mkdir(parents=True, exist_ok=True)
def sim(*args, check=True):
    return subprocess.run(['xcrun', 'simctl', *args], check=check)
sim('install', device, str(build / 'Build/Products/Dev-iphonesimulator/pippipgo.app'))
sim('status_bar', device, 'override', '--time', '9:41', '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3', '--batteryState', 'charged', '--batteryLevel', '100')
for index, screen in enumerate(['trips', 'details', 'chat', 'voice', 'translate', 'budget'], 1):
    sim('terminate', device, bundle, check=False)
    sim('launch', device, bundle, screen)
    time.sleep(8)
    sim('io', device, 'screenshot', str(out / f'{index:02d}-{screen}.png'))
sim('terminate', device, bundle)
sim('status_bar', device, 'clear')
print(out)
