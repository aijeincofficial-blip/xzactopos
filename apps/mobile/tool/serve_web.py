"""Static server for the Flutter web build: correct .wasm MIME type, no HTTP caching. Usage: serve.py <dir> <port>"""
import functools
import http.server
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.wasm': 'application/wasm',
        '.js': 'text/javascript',
        '.mjs': 'text/javascript',
        '.json': 'application/json',
    }

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()


root, port = sys.argv[1], int(sys.argv[2])
http.server.ThreadingHTTPServer(('127.0.0.1', port), functools.partial(Handler, directory=root)).serve_forever()
