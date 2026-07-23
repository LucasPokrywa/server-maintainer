#!/bin/bash

set -e

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

pip install -r requirements.txt

ansible-galaxy collection install ansible.posix

TAGS="untagged,ssh,cron,monitor,ports,packages"

ansible-playbook -v -i inventory.yaml playbook.yaml -t "$TAGS"