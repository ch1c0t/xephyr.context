#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  build-essential \
  libtesseract-dev \
  tesseract-ocr-eng
