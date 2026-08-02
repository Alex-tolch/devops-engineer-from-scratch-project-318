# Ansible

```bash
cp inventory.ini.example inventory.ini
cp group_vars/app/vault.yml.example group_vars/app/vault.yml
cp ../ansible/.vault-password.example .vault-password
ansible-vault encrypt group_vars/app/vault.yml

make -C .. ansible-setup
make -C .. server-prepare
make -C .. server-deploy
```

Vault password: see `.vault-password.example`.
