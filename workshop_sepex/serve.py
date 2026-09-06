#!/usr/bin/env python3
"""
Minimal HTTP server to view the Quarto Reveal.js presentation.
Serves workshop_sepex directory and automatically redirects '/' to '/drift_diffusion_modeling.html'.
"""

import http.server
import os
import socketserver
import sys

DIRECTORY = os.path.dirname(os.path.abspath(__file__))
DEFAULT_PORT = 8889

class PresentationHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # Automatically redirect root to the presentation HTML
        if self.path in ("/", ""):
            self.send_response(302)
            self.send_header("Location", "/drift_diffusion_modeling.html")
            self.end_headers()
            return
        return super().do_GET()

def run_server(port=DEFAULT_PORT):
    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", port), PresentationHandler) as httpd:
            print(f"Serving workshop presentation at http://localhost:{port}/")
            print(f"Direct link: http://localhost:{port}/drift_diffusion_modeling.html")
            print("Press Ctrl+C to stop the server.")
            httpd.serve_forever()
    except OSError as e:
        if e.errno == 98:  # Address already in use
            alt_port = port + 1
            print(f"Port {port} in use, trying port {alt_port}...")
            run_server(alt_port)
        else:
            raise e

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
    try:
        run_server(port)
    except KeyboardInterrupt:
        print("\nShutting down webserver.")
