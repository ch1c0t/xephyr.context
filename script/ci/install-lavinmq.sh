#!/usr/bin/env bash
set -euo pipefail

curl -fsSL https://packagecloud.io/install/repositories/cloudamqp/lavinmq/script.deb.sh | sudo bash
sudo apt-get update
sudo apt-get install -y lavinmq
sudo systemctl stop lavinmq.service || true
