#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cardano Web Hot Wallet (PWA) Local Server
Chạy máy chủ cục bộ phục vụ Cardano Hot Wallet trên trình duyệt máy tính và điện thoại di động (iOS / Android).
"""

import http.server
import socketserver
import os
import sys
import socket

PORT = 8088
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web_hot_wallet")
if not os.path.exists(WEB_DIR):
    WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output", "web_hot_wallet")

class PwaHttpHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def main():
    if os.path.exists(WEB_DIR):
        os.chdir(WEB_DIR)
    local_ip = get_local_ip()
    
    print("=" * 65)
    print("      CARDANO HOT WATCH-ONLY WALLET (WEB PWA EDITION)")
    print("=" * 65)
    print(f"[*] Thư mục phục vụ: {WEB_DIR}")
    print(f"[*] Truy cập trên Máy tính:  http://localhost:{PORT}")
    print(f"[*] Truy cập trên Điện thoại (Wi-Fi): http://{local_ip}:{PORT}")
    print("-" * 65)
    print("LƯU Ý VỀ CAMERA TRÊN TRÌNH DUYỆT DI ĐỘNG (iOS Safari / Android):")
    print("1. Trình duyệt iOS Safari yêu cầu HTTPS để cấp quyền mở Camera.")
    print("2. Để dùng đầy đủ tính năng Camera trực tiếp trên iPhone:")
    print("   - Đẩy thư mục 'web_hot_wallet' lên GitHub Pages hoặc Cloudflare Pages (Miễn phí, có sẵn HTTPS).")
    print("   - Hoặc dùng Cloudflare Tunnel: npx untun@latest tunnel --port 8088")
    print("3. Nếu truy cập qua HTTP nội bộ, bạn có thể dùng nút 'Tải Ảnh QR' hoặc 'Dán Hex' có sẵn!")
    print("=" * 65)
    print(f"Đang lắng nghe tại cổng {PORT}... (Nhấn Ctrl+C để dừng)")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), PwaHttpHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[!] Đã dừng máy chủ Cardano Web Hot Wallet.")

if __name__ == "__main__":
    main()
