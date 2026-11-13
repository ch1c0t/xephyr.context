#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  gnupg \
  libtesseract-dev \
  libx11-dev \
  tesseract-ocr-eng \
  xvfb \
  x11-utils \
  x11-xserver-utils
