test:
	./gradlew test

start: run

run:
	./gradlew bootRun

update-gradle:
	./gradlew wrapper --gradle-version 9.2.1

update-deps:
	./gradlew refreshVersions

install:
	./gradlew dependencies

build:
	./gradlew build

lint:
	./gradlew spotlessCheck

lint-fix:
	./gradlew spotlessApply

DOCKER_IMAGE ?= ghcr.io/alex-tolch/devops-engineer-from-scratch-project-318:latest
ANSIBLE_DIR := ansible
VAULT_PASS_FILE := /tmp/hexlet-ansible-vault-pass
ANSIBLE_PLAYBOOK = cd $(ANSIBLE_DIR) && ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS_FILE) ansible-playbook -i inventory.ini playbook.yml
ANSIBLE_PROMETHEUS = cd $(ANSIBLE_DIR) && ANSIBLE_VAULT_PASSWORD_FILE=$(VAULT_PASS_FILE) ansible-playbook -i inventory.ini playbook.yml --limit monitoring
TERRAFORM_DIR := terraform

.PHONY: test run build lint docker-build docker-run docker-upload-server compose-up compose-down \
	terraform-init terraform-plan terraform-apply terraform-destroy \
	ansible-setup ansible-prepare ansible-deploy ansible-monitoring ansible-prometheus ansible-grafana server-prepare server-deploy server-monitoring server-grafana

docker-build:
	docker build -t $(DOCKER_IMAGE) .

docker-run:
	docker run --rm -p 8080:8080 -p 9090:9090 \
		-e SPRING_PROFILES_ACTIVE=dev \
		$(DOCKER_IMAGE)

# GHCR pull on the droplet often fails (private image). Build locally, load over SSH, then recreate.
docker-upload-server:
	bash scripts/docker-upload-server.sh

compose-up:
	cp -n .env.example .env 2>/dev/null || true
	DOCKER_IMAGE=$(DOCKER_IMAGE) docker compose up --build -d

compose-down:
	docker compose down -v

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
	$(ANSIBLE_PROMETHEUS) --tags "setup,prometheus,grafana"

server-grafana: ansible-setup ansible-grafana

ansible-vault-encrypt:
	cd $(ANSIBLE_DIR) && ansible-vault encrypt group_vars/app/vault.yml

ansible-vault-edit:
	cd $(ANSIBLE_DIR) && ansible-vault edit group_vars/app/vault.yml
