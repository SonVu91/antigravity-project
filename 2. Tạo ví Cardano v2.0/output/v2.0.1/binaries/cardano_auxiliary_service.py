import http.server
import json
import ctypes
import os
import sys
import time

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# Locate and load rust_cardano_core.dll strictly from trusted absolute paths
current_dir = os.path.dirname(os.path.abspath(__file__))
dll_paths = [
    os.path.join(current_dir, "rust_cardano_core.dll"),
    os.path.join(current_dir, "rust_cardano_core", "target", "release", "rust_cardano_core.dll"),
    r"E:\cargo_target\release\rust_cardano_core.dll",
]

lib_cardano = None
for p in dll_paths:
    if os.path.exists(p):
        try:
            lib_cardano = ctypes.cdll.LoadLibrary(p)
            print(f"[Auxiliary] Loaded native Rust core from: {p}")
            break
        except Exception as e:
            print(f"[Auxiliary] Failed loading {p}: {e}")

if not lib_cardano:
    print("[Auxiliary] Warning: Could not load rust_cardano_core.dll! Fallback mode enabled.")
else:
    # Setup C FFI types
    lib_cardano.cardano_core_generate_mnemonic.argtypes = [ctypes.c_uint32]
    lib_cardano.cardano_core_generate_mnemonic.restype = ctypes.c_void_p

    lib_cardano.cardano_core_validate_mnemonic.argtypes = [ctypes.c_char_p]
    lib_cardano.cardano_core_validate_mnemonic.restype = ctypes.c_bool

    lib_cardano.cardano_core_create_wallet.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool, ctypes.c_uint32, ctypes.c_uint32]
    lib_cardano.cardano_core_create_wallet.restype = ctypes.c_void_p

    if hasattr(lib_cardano, "cardano_core_create_wallet_ext"):
        lib_cardano.cardano_core_create_wallet_ext.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_bool]
        lib_cardano.cardano_core_create_wallet_ext.restype = ctypes.c_void_p

    lib_cardano.cardano_core_parse_transaction.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool]
    lib_cardano.cardano_core_parse_transaction.restype = ctypes.c_void_p

    lib_cardano.cardano_core_sign_transaction.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool, ctypes.c_uint32, ctypes.c_uint32]
    lib_cardano.cardano_core_sign_transaction.restype = ctypes.c_void_p

    if hasattr(lib_cardano, "cardano_core_sign_transaction_ext"):
        lib_cardano.cardano_core_sign_transaction_ext.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_bool]
        lib_cardano.cardano_core_sign_transaction_ext.restype = ctypes.c_void_p

    if hasattr(lib_cardano, "cardano_core_sign_transaction_v2"):
        lib_cardano.cardano_core_sign_transaction_v2.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_bool, ctypes.c_bool]
        lib_cardano.cardano_core_sign_transaction_v2.restype = ctypes.c_void_p

    lib_cardano.cardano_core_verify_signed_tx.argtypes = [ctypes.c_char_p]
    lib_cardano.cardano_core_verify_signed_tx.restype = ctypes.c_void_p

    lib_cardano.cardano_core_verify_change.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_bool]
    lib_cardano.cardano_core_verify_change.restype = ctypes.c_void_p

    lib_cardano.cardano_core_create_sample_conway_tx.argtypes = [ctypes.c_char_p, ctypes.c_uint64, ctypes.c_uint64]
    lib_cardano.cardano_core_create_sample_conway_tx.restype = ctypes.c_void_p

    lib_cardano.cardano_core_free_string.argtypes = [ctypes.c_void_p]
    lib_cardano.cardano_core_free_string.restype = None

    def ffi_call_json(func, *args):
        ptr = func(*args)
        if not ptr:
            return {"success": False, "error": "Null pointer returned from native core"}
        try:
            raw_str = ctypes.string_at(ptr).decode("utf-8")
            return json.loads(raw_str)
        finally:
            lib_cardano.cardano_core_free_string(ptr)


class CardanoRequestHandler(http.server.BaseHTTPRequestHandler):
    ALLOWED_ORIGINS = {
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:8081",
        "http://127.0.0.1:8081",
        "http://localhost:8082",
        "http://127.0.0.1:8082",
    }

    def _send_cors_headers(self):
        req_origin = self.headers.get("Origin", "")
        if req_origin in self.ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", req_origin)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Cardano-AirGap-Bridge")
        self.send_header("Vary", "Origin")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        req_origin = self.headers.get("Origin", "")
        if req_origin and req_origin not in self.ALLOWED_ORIGINS:
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"403 Forbidden: Untrusted Origin")
            return

        if self.path == "/health":
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "native_loaded": lib_cardano is not None}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        req_origin = self.headers.get("Origin", "")
        sec_fetch_site = self.headers.get("Sec-Fetch-Site", "")
        if (req_origin and req_origin not in self.ALLOWED_ORIGINS) or sec_fetch_site == "cross-site":
            self.send_response(403)
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "error": "Forbidden: Cross-site or untrusted origin request blocked"}).encode())
            return

        MAX_BODY_BYTES = 65536
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length > MAX_BODY_BYTES:
            self.send_response(413)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "error": "Payload Too Large: exceeds 64KB limit"}).encode())
            return

        body_bytes = self.rfile.read(content_length)
        req_json = {}
        if body_bytes:
            try:
                req_json = json.loads(body_bytes.decode("utf-8"))
            except Exception:
                pass

        res_obj = {"success": False, "error": "Unknown endpoint"}

        try:
            if not lib_cardano:
                res_obj = {"success": False, "error": "CRITICAL: Native cryptographic core (rust_cardano_core.dll) not loaded"}
            elif self.path == "/api/generate_mnemonic":
                word_count = req_json.get("word_count", 24)
                res_obj = ffi_call_json(lib_cardano.cardano_core_generate_mnemonic, word_count)

            elif self.path == "/api/validate_mnemonic":
                phrase = req_json.get("phrase", "")
                valid = lib_cardano.cardano_core_validate_mnemonic(phrase.encode("utf-8"))
                res_obj = {"success": True, "data": valid}

            elif self.path in ("/api/create_wallet", "/api/create_wallet_ext"):
                phrase = req_json.get("phrase", "")
                passphrase = req_json.get("passphrase", "")
                is_testnet = req_json.get("is_testnet", True)
                account_index = int(req_json.get("account_index", 0))
                address_index = int(req_json.get("address_index", 0))
                use_icarus = bool(req_json.get("use_icarus", False))
                if hasattr(lib_cardano, "cardano_core_create_wallet_ext"):
                    res_obj = ffi_call_json(
                        lib_cardano.cardano_core_create_wallet_ext,
                        phrase.encode("utf-8"),
                        passphrase.encode("utf-8"),
                        is_testnet,
                        account_index,
                        address_index,
                        use_icarus
                    )
                else:
                    res_obj = ffi_call_json(
                        lib_cardano.cardano_core_create_wallet,
                        phrase.encode("utf-8"),
                        passphrase.encode("utf-8"),
                        is_testnet,
                        account_index,
                        address_index
                    )

            elif self.path == "/api/parse_tx":
                cbor = req_json.get("cbor_hex", "")
                xpub = req_json.get("account_xpub_hex", "")
                is_testnet = req_json.get("is_testnet", True)
                res_obj = ffi_call_json(
                    lib_cardano.cardano_core_parse_transaction,
                    cbor.encode("utf-8"),
                    xpub.encode("utf-8"),
                    is_testnet
                )

            elif self.path in ("/api/sign_tx", "/api/sign_tx_ext"):
                cbor = req_json.get("cbor_hex", "")
                phrase = req_json.get("mnemonic", "")
                passphrase = req_json.get("passphrase", "")
                sign_stake = req_json.get("sign_stake", False)
                account_index = int(req_json.get("account_index", 0))
                address_index = int(req_json.get("address_index", 0))
                is_testnet = bool(req_json.get("is_testnet", True))
                use_icarus = bool(req_json.get("use_icarus", False))
                if hasattr(lib_cardano, "cardano_core_sign_transaction_v2"):
                    res_obj = ffi_call_json(
                        lib_cardano.cardano_core_sign_transaction_v2,
                        cbor.encode("utf-8"),
                        phrase.encode("utf-8"),
                        passphrase.encode("utf-8"),
                        sign_stake,
                        account_index,
                        address_index,
                        is_testnet,
                        use_icarus
                    )
                elif hasattr(lib_cardano, "cardano_core_sign_transaction_ext"):
                    res_obj = ffi_call_json(
                        lib_cardano.cardano_core_sign_transaction_ext,
                        cbor.encode("utf-8"),
                        phrase.encode("utf-8"),
                        passphrase.encode("utf-8"),
                        sign_stake,
                        account_index,
                        address_index,
                        use_icarus
                    )
                else:
                    res_obj = ffi_call_json(
                        lib_cardano.cardano_core_sign_transaction,
                        cbor.encode("utf-8"),
                        phrase.encode("utf-8"),
                        passphrase.encode("utf-8"),
                        sign_stake,
                        account_index,
                        address_index
                    )

            elif self.path == "/api/verify_signed_tx":
                signed_cbor = req_json.get("signed_cbor_hex", "")
                res_obj = ffi_call_json(
                    lib_cardano.cardano_core_verify_signed_tx,
                    signed_cbor.encode("utf-8")
                )

            elif self.path == "/api/verify_change":
                change_addr = req_json.get("change_address", "")
                xpub = req_json.get("account_xpub_hex", "")
                is_testnet = req_json.get("is_testnet", True)
                res_obj = ffi_call_json(
                    lib_cardano.cardano_core_verify_change,
                    change_addr.encode("utf-8"),
                    xpub.encode("utf-8"),
                    is_testnet
                )

            elif self.path == "/api/create_sample_conway_tx":
                rec_addr = req_json.get("recipient_addr", "")
                send_lovelace = req_json.get("send_lovelace", 10000000)
                fee_lovelace = req_json.get("fee_lovelace", 180000)
                res_obj = ffi_call_json(
                    lib_cardano.cardano_core_create_sample_conway_tx,
                    rec_addr.encode("utf-8"),
                    send_lovelace,
                    fee_lovelace
                )

        except Exception as e:
            res_obj = {"success": False, "error": str(e)}

        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(res_obj).encode("utf-8"))

    def log_message(self, format, *args):
        # Concise logging
        print(f"[Auxiliary API] {self.command} {self.path}")


if __name__ == "__main__":
    port = 5050
    server_address = ("127.0.0.1", port)
    http.server.HTTPServer.allow_reuse_address = True
    httpd = http.server.HTTPServer(server_address, CardanoRequestHandler)
    print(f"==================================================")
    print(f" Cardano Air-Gap Native Core Bridge Auxiliary Service")
    print(f" Listening on http://127.0.0.1:{port}")
    print(f"==================================================")
    sys.stdout.flush()
    try:
        while True:
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"[Auxiliary] Server error, restarting listener: {e}")
                time.sleep(1)
    finally:
        httpd.server_close()
