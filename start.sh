#!/bin/bash

set -e

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

pip install -r requirements.txt

ansible-galaxy collection install ansible.posix

TAGS="ssh,cron,monitor,ports,packages"

while getopts "s" opt; do
    case $opt in
        s)
            TAGS="$TAGS,selinux"
            ;;
    esac
done

ansible-playbook -v -i inventory.yaml playbook.yaml -t "$TAGS"