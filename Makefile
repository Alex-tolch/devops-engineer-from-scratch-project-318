DOCKER_IMAGE ?= ghcr.io/alex-tolch/devops-engineer-from-scratch-project-318:latest
APP_REPO ?= https://github.com/hexlet-components/project-devops-deploy.git
APP_REF ?= main
ANSIBLE_DIR := ansible
VAULT_PASS_FILE := /tmp/hexlet-ansible-vault-pass
ANSIBLE_PLAYBOOK = cd $(ANSIBLE_DIR) && ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS_FILE) ansible-playbook -i inventory.ini playbook.yml
ANSIBLE_PROMETHEUS = cd $(ANSIBLE_DIR) && ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS_FILE) ansible-playbook -i inventory.ini playbook.yml --limit monitoring
TERRAFORM_DIR := terraform

ansible-lint:
	cd $(ANSIBLE_DIR) && ansible-lint .

ansible-test:
	bash scripts/ansible_ping.sh

smoke:
	bash scripts/smoke.sh

verify: ansible-lint ansible-test smoke

.PHONY: docker-build docker-run docker-upload-server \
	terraform-init terraform-plan terraform-apply terraform-destroy \
	ansible-setup ansible-prepare ansible-deploy ansible-monitoring ansible-prometheus ansible-grafana \
	ansible-lint ansible-test smoke verify docker-upload-server \
	server-prepare server-deploy server-monitoring server-grafana deploy grafana-test-alert \
	ansible-vault-encrypt ansible-vault-edit

docker-build:
	docker build \
		--build-arg APP_REPO=$(APP_REPO) \
		--build-arg APP_REF=$(APP_REF) \
		-t $(DOCKER_IMAGE) .

docker-run:
	docker run --rm -p 8080:8080 -p 9090:9090 \
		-e SPRING_PROFILES_ACTIVE=dev \
		$(DOCKER_IMAGE)

# Build locally, load over SSH when GHCR pull on the droplet is denied.
docker-upload-server:
	bash scripts/docker-upload-server.sh

terraform-init:
	cd $(TERRAFORM_DIR) && terraform init

terraform-plan:
	cd $(TERRAFORM_DIR) && terraform plan

terraform-apply:
	cd $(TERRAFORM_DIR) && terraform apply

terraform-destroy:
	cd $(TERRAFORM_DIR) && terraform destroy

ansible-setup:
	@test -f $(ANSIBLE_DIR)/.vault-password || (echo "Missing ansible/.vault-password"; exit 1)
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml

ansible-prepare:
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	$(ANSIBLE_PLAYBOOK) --tags setup

ansible-deploy:
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	$(ANSIBLE_PLAYBOOK) --tags deploy

ansible-monitoring:
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	$(ANSIBLE_PLAYBOOK) --tags "deploy,monitoring"

ansible-prometheus:
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	$(ANSIBLE_PROMETHEUS) --tags "setup,prometheus"

ansible-grafana:
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	$(ANSIBLE_PROMETHEUS) --tags "grafana"

server-prepare: ansible-setup ansible-prepare

server-deploy: ansible-setup ansible-deploy

server-monitoring: ansible-setup
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	$(ANSIBLE_PROMETHEUS) --tags "setup,prometheus,loki,grafana"

server-grafana: ansible-setup ansible-grafana

deploy: server-prepare server-deploy server-monitoring

grafana-test-alert:
	@cp $(ANSIBLE_DIR)/.vault-password $(VAULT_PASS_FILE)
	@chmod 644 $(VAULT_PASS_FILE)
	@echo "Enabling test alert (bull-test-alert) for 2 minutes..."
	cd $(ANSIBLE_DIR) && ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS_FILE) ansible-playbook -i inventory.ini playbook.yml --limit monitoring --tags grafana -e grafana_test_alert_paused=false
	@sleep 120
	@echo "Pausing test alert again..."
	cd $(ANSIBLE_DIR) && ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS_FILE) ansible-playbook -i inventory.ini playbook.yml --limit monitoring --tags grafana -e grafana_test_alert_paused=true
	@echo "Done. Check ntfy topic from vault_grafana_ntfy_topic."

ansible-vault-encrypt:
	cd $(ANSIBLE_DIR) && ansible-vault encrypt group_vars/app/vault.yml

ansible-vault-edit:
	cd $(ANSIBLE_DIR) && ansible-vault edit group_vars/app/vault.yml
