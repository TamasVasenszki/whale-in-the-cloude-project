#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y curl jq