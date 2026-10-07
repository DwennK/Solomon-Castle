"""Create local deliverables without caches, test saves or research binaries."""
from pathlib import Path
import zipfile, hashlib
root=Path(__file__).resolve().parents[1]
out=root/'outputs';out.mkdir(exist_ok=True)
licenses=list((root/'docs/licenses').glob('*.txt'))+list((root/'assets/fonts').glob('*OFL.txt'))
notice='The Tower of Ash 0.2.0\n\nmacOS: open The Tower of Ash.app. Ad-hoc signed, not notarized.\nWindows: run La-Tour-des-Cendres.exe. Unsigned x86-64 build; Windows testing required.\n\nControls: WASD/ZQSD, mouse + left click, E interact, T village, I inventory, K grimoire, R/F potions, 1/2/3 rituals, Esc pause.\nFull documentation is included in the source archive.\n'
mac=out/'La-Tour-des-Cendres-macOS.zip'
if mac.exists():
 with zipfile.ZipFile(mac,'a',zipfile.ZIP_DEFLATED) as z:
  if 'README.txt' not in z.namelist():
   z.writestr('README.txt',notice)
   for p in licenses:z.write(p,'Licenses/'+p.name)
win=out/'La-Tour-des-Cendres-Windows.zip'
with zipfile.ZipFile(win,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 z.write(out/'windows/La-Tour-des-Cendres.exe','La-Tour-des-Cendres.exe')
 z.writestr('README.txt',notice)
 for p in licenses:z.write(p,'Licenses/'+p.name)
source=out/'La-Tour-des-Cendres-Sources.zip'
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in root.rglob('*'):
  if not p.is_file():continue
  rel=p.relative_to(root)
  if any(part in {'.godot','.git','.tools-venv','outputs','__pycache__','research'} for part in rel.parts):continue
  if p.name=='.DS_Store':continue
  z.write(p,'La-Tour-des-Cendres/'+rel.as_posix())
for p in [mac,win,source]:
 if p.exists():print(p.name,p.stat().st_size,hashlib.sha256(p.read_bytes()).hexdigest())
