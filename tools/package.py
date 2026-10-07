"""Create local deliverables without caches, test saves or research binaries."""
from pathlib import Path
import zipfile, hashlib
root=Path(__file__).resolve().parents[1]
out=root/'outputs';out.mkdir(exist_ok=True)
licenses=list((root/'docs/licenses').glob('*.txt'))+list((root/'assets/fonts').glob('*OFL.txt'))
notice='La Tour des Cendres 0.1.0\n\nmacOS : ouvrir La Tour des Cendres.app. Signature ad hoc, non notarisee.\nWindows : lancer La-Tour-des-Cendres.exe. Binaire x86-64 non signe, non teste sur Windows.\n\nCommandes : WASD/ZQSD, souris + clic gauche, E interaction, T village, I inventaire, K grimoire, R/F potions, 1/2/3 rituels, Echap pause.\nDocumentation complete dans l archive source.\n'
mac=out/'La-Tour-des-Cendres-macOS.zip'
if mac.exists():
 with zipfile.ZipFile(mac,'a',zipfile.ZIP_DEFLATED) as z:
  if 'LIRE-MOI.txt' not in z.namelist():
   z.writestr('LIRE-MOI.txt',notice)
   for p in licenses:z.write(p,'Licences/'+p.name)
win=out/'La-Tour-des-Cendres-Windows.zip'
with zipfile.ZipFile(win,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 z.write(out/'windows/La-Tour-des-Cendres.exe','La-Tour-des-Cendres.exe')
 z.writestr('LIRE-MOI.txt',notice)
 for p in licenses:z.write(p,'Licences/'+p.name)
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
