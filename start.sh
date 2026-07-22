#!/bin/bash

python3 -m venv .venv

source .venv/bin/activate

pip install -r requirements.txt

ansible-galaxy collection install ansible.posix

ansible-playbook -v -i inventory.yaml playbook.yaml