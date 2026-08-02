# Ansible

```bash
cp inventory.ini.example inventory.ini
cp group_vars/app/vault.yml.example group_vars/app/vault.yml   # first time only
cp .vault-password.example .vault-password
ansible-vault encrypt group_vars/app/vault.yml
# add vault_metrics_basic_auth_password via: make ansible-vault-edit

make -C .. ansible-setup
make -C .. server-prepare    # docker, app (localhost:9091), node_exporter, nginx :9090
make -C .. server-deploy     # application container only
make -C .. ansible-monitoring  # redeploy app + monitoring stack
```

| Role | Purpose |
|------|---------|
| `roles/node_exporter` | Prometheus Node Exporter (system metrics, port 9100) |
| `roles/metrics_proxy` | Nginx reverse proxy to Actuator on 9090, JSON logs, basic auth |

Vault password: see `.vault-password.example`.
