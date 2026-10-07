"""Build the central English source-language translation catalogue."""
import re,csv,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
strings=set()
for path in list((root/'scripts').glob('*.gd'))+list((root/'resources').glob('*/*.tres')):
 if path.name == 'legacy_english.gd': continue
 for m in re.finditer(r'"(?:[^"\\]|\\.)*"',path.read_text()):
  try:value=json.loads(m.group())
  except:continue
  if len(value)>2 and not value.startswith(('res://','user://')) and (' ' in value or re.search('[éèàâêîôûçÉÀœ]',value)) and not any(x in value for x in ['shader_type','\t','%d,%d']): strings.add(value)
p=root/'resources/localization';p.mkdir(exist_ok=True)
with (p/'messages.csv').open('w',newline='') as f:
 w=csv.writer(f,lineterminator="\n",quoting=csv.QUOTE_ALL);w.writerow(['key','en']);w.writerows((v,v) for v in sorted(strings))
print(len(strings),'source strings')
