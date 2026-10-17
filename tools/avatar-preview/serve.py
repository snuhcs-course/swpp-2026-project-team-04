"""Local-only avatar preview. No external network dependency."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from functools import partial
from urllib.parse import unquote, urlsplit
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--port',type=int,default=8765)
args=parser.parse_args()
root=Path(__file__).resolve().parent
class LocalHandler(SimpleHTTPRequestHandler):
    # Windows registry MIME mappings can classify .mjs as text/plain.
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,'.mjs':'text/javascript','.js':'text/javascript','.wasm':'application/wasm','.task':'application/octet-stream'}
    def translate_path(self, path):
        # Serve the committed Flutter assets without a machine-local junction.
        route=unquote(urlsplit(path).path)
        if route == '/native-assets' or route.startswith('/native-assets/'):
            assets=(root/'../../gymrats_app/assets/avatar').resolve()
            target=(assets/route[len('/native-assets'):].lstrip('/')).resolve()
            if not target.is_relative_to(assets):
                return str(root/'__blocked_asset_path__')
            return str(target)
        return super().translate_path(path)
print(f'Avatar Lab: http://127.0.0.1:{args.port}',flush=True)
ThreadingHTTPServer(('127.0.0.1',args.port),partial(LocalHandler,directory=str(root))).serve_forever()
