"""Download selected author-hosted avatar files; preserve sources and licenses."""
import json, re, urllib.request, urllib.parse, http.cookiejar, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SOURCE=ROOT/'source-assets'
SOURCE.mkdir(exist_ok=True)
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
opener.addheaders=[('User-Agent','Mozilla/5.0')]
def get(url):
    with opener.open(url,timeout=90) as response:return response.read()
def post(url,data=None):
    req=urllib.request.Request(url,urllib.parse.urlencode(data or {}).encode(),headers={'Referer':url.rsplit('/',1)[0]})
    with opener.open(req,timeout=90) as response:return response.read()
def save(url,name):
    path=SOURCE/name
    if not path.exists():path.write_bytes(get(url))
    print(name,path.stat().st_size,flush=True)
    if path.suffix=='.zip':
        with zipfile.ZipFile(path) as archive:
            dest=SOURCE/path.stem
            for member in archive.infolist():
                resolved=(dest/member.filename).resolve()
                if not resolved.is_relative_to(dest.resolve()):raise ValueError('Unsafe archive path')
            archive.extractall(dest)
        print('contents',archive.namelist()[:35],flush=True)
save('https://opengameart.org/sites/default/files/animated%20humanoid.zip','xcvg.zip')
release=json.loads(get('https://api.github.com/repos/gdquest-demos/godot-3d-mannequin/releases/latest'))
for asset in release['assets']:
    if asset['name'].endswith('.blend'):save(asset['browser_download_url'],'mannequiny.blend')
save('https://raw.githubusercontent.com/gdquest-demos/godot-3d-mannequin/master/LICENSE','mannequiny-LICENSE.txt')
for slug,name,upload in [('https://donitz.itch.io/corebreaker-robot-model','robot',17297137),('https://mrlentereng.itch.io/rigged-low-poly-astronaut','astronaut',None)]:
    if (SOURCE/(name+'.zip')).exists():continue
    page=get(slug).decode()
    (SOURCE/(name+'-source.html')).write_text(page,encoding='utf-8')
    if upload is None:
        csrf=re.search(r'<meta[^>]+name="csrf_token"[^>]+value="([^"]+)"',page)
        if not csrf:csrf=re.search(r'<meta[^>]+value="([^"]+)"[^>]+name="csrf_token"',page)
        response=json.loads(post(slug+'/download_url',{'csrf_token':csrf.group(1)}))
        download_page=get(response['url']).decode()
        uploads=re.findall(r'data-upload_id="(\d+)"',download_page)
        if not uploads:raise RuntimeError('No free download found for '+name)
        upload=int(uploads[0])
    data=json.loads(post(slug+'/file/'+str(upload)))
    save(data['url'],name+'.zip')
