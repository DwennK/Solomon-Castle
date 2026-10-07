"""Technical atlas slicing only. Original painted source: built-in ImageGen."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
out = root / 'assets/art/v2'
names = ['mage','skeleton','archer','zombie','ghoul','sorcerer','knight','imp','ghost','king','plague','demon','lich','merchant','teacher','healer']
groups = {
    'characters-source.png': names,
    'props-source.png': ['chest','chest_open','torch','urn','portal','stairs','gold','health','mana','staff','ring','book','missile','fire','lightning','ice'],
    'rituals-source.png': ['fire_missile','flame_lash','steam','ball_lightning','frost_missile','blizzard','teleport','shield','circle','freeze','ring_fire','acid','undead','level_up','speed','archmage'],
}
for source, ids in groups.items():
    im = Image.open(out / source).convert('RGBA')
    assert im.getchannel('A').getextrema()[0] == 0, 'Real alpha required'
    for i, name in enumerate(ids):
        x, y = i % 4, i // 4
        crop = im.crop((round(x*im.width/4), round(y*im.height/4), round((x+1)*im.width/4), round((y+1)*im.height/4)))
        bounds = crop.getchannel('A').point(lambda a: 255 if a > 24 else 0).getbbox()
        assert bounds, name
        crop = crop.crop(bounds)
        crop.thumbnail((360,360), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (384,384))
        canvas.alpha_composite(crop, ((384-crop.width)//2, 376-crop.height))
        canvas.save(out / (name+'.png'))
    print(source, len(ids), 'assets sliced, alpha preserved')
