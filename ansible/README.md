# Ansible

```bash
cp inventory.ini.example inventory.ini
# Set app + monitoring IPs from: terraform -chdir=terraform output -raw droplet_ip / monitoring_ip
cp group_vars/app/vault.yml.example group_vars/app/vault.yml   # first time only
cp .vault-password.example .vault-password
ansible-vault encrypt group_vars/app/vault.yml
# add vault_metrics_basic_auth_password via: make ansible-vault-edit

make -C .. ansible-setup
make -C .. server-prepare       # app: docker, app, node_exporter, nginx
make -C .. server-deploy        # application container only
make -C .. ansible-monitoring   # redeploy app + exporters on app host
make -C .. server-monitoring    # Prometheus on monitoring host (one command)
```

| Role | Host | Purpose |
|------|------|---------|
| `roles/node_exporter` | app | Node Exporter (9100) |
| `roles/metrics_proxy` | app | Nginx → Actuator on 9090, basic auth |
| `roles/prometheus` | monitoring | Prometheus in Docker, network `monitoring` |

Scrape targets and jobs: [`group_vars/monitoring/vars.yml`](group_vars/monitoring/vars.yml). Alert rules: [`roles/prometheus/files/alerts.yml`](roles/prometheus/files/alerts.yml). Config is validated with **promtool** during the play.

Vault password: see `.vault-password.example`. Scrape credentials reuse `vault_metrics_basic_auth_password` from `group_vars/app/vault.yml`.
