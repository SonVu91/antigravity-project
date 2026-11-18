import subprocess
import sys
import time
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    print("[Cluster] Starting Cardano Auxiliary Service and Dual Wallets...")
    sys.stdout.flush()
    p_aux = subprocess.Popen([sys.executable, os.path.join(BASE_DIR, "cardano_auxiliary_service.py")])
    time.sleep(1)
    p_web = subprocess.Popen([sys.executable, os.path.join(BASE_DIR, "serve_wallets.py"), "--no-browser"])
    
    try:
        while True:
            if p_aux.poll() is not None:
                print("[Cluster] Auxiliary service exited, restarting...")
                sys.stdout.flush()
                p_aux = subprocess.Popen([sys.executable, os.path.join(BASE_DIR, "cardano_auxiliary_service.py")])
            if p_web.poll() is not None:
                print("[Cluster] Web servers exited, restarting...")
                sys.stdout.flush()
                p_web = subprocess.Popen([sys.executable, os.path.join(BASE_DIR, "serve_wallets.py"), "--no-browser"])
            time.sleep(2)
    except (KeyboardInterrupt, SystemExit):
        p_aux.terminate()
        p_web.terminate()

if __name__ == "__main__":
    main()
