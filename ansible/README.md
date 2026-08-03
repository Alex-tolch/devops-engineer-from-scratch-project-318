# Ansible

```bash
cp inventory.ini.example inventory.ini
# Set app + monitoring IPs from: terraform -chdir=terraform output -raw droplet_ip / monitoring_ip
cp group_vars/app/vault.yml.example group_vars/app/vault.yml   # first time only
cp .vault-password.example .vault-password
ansible-vault encrypt group_vars/app/vault.yml
# add vault_metrics_basic_auth_password, vault_grafana_admin_password, vault_grafana_ntfy_topic via: make ansible-vault-edit

make -C .. ansible-setup
make -C .. server-prepare       # app: docker, app, node_exporter, nginx
make -C .. server-deploy        # application container only
make -C .. ansible-monitoring   # redeploy app + exporters on app host
make -C .. server-monitoring    # Prometheus + Grafana on monitoring host
make -C .. server-grafana       # Grafana / dashboards / alerting only
make -C .. grafana-test-alert   # 2-minute ntfy notification test
```

| Role | Host | Purpose |
|------|------|---------|
| `roles/node_exporter` | app | Node Exporter (9100) |
| `roles/metrics_proxy` | app | Nginx → Actuator on 9090, basic auth |
| `roles/prometheus` | monitoring | Prometheus in Docker, network `monitoring` |
| `roles/grafana` | monitoring | Grafana, dashboards, alerting, `ntfy-relay` |

Scrape targets: [`group_vars/monitoring/vars.yml`](group_vars/monitoring/vars.yml). Prometheus alert rules: [`roles/prometheus/files/alerts.yml`](roles/prometheus/files/alerts.yml). Grafana alerting: [`roles/grafana/templates/provisioning/alerting/`](roles/grafana/templates/provisioning/alerting/). Config is validated with **promtool** during the Prometheus play.

Vault (`group_vars/app/vault.yml`): `vault_metrics_basic_auth_password`, `vault_grafana_admin_password`, `vault_grafana_ntfy_topic`. Password file: `.vault-password.example`.
