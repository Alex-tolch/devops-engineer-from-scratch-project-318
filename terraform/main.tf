terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.36"
    }
  }
}

provider "digitalocean" {
  token             = var.do_token
  spaces_access_id  = var.spaces_access_id != "" ? var.spaces_access_id : null
  spaces_secret_key = var.spaces_secret_key != "" ? var.spaces_secret_key : null
}

resource "digitalocean_vpc" "main" {
  name     = "${var.project_name}-vpc"
  region   = var.region
  ip_range = "10.10.0.0/16"
}

resource "digitalocean_droplet" "app" {
  name     = "${var.project_name}-app"
  region   = var.region
  size     = var.droplet_size
  image    = "ubuntu-24-04-x64"
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [var.ssh_key_fingerprint]

  tags = ["bulletin-app", var.project_name]
}

resource "digitalocean_droplet" "monitoring" {
  name     = "${var.project_name}-monitoring"
  region   = var.region
  size     = var.droplet_size
  image    = "ubuntu-24-04-x64"
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [var.ssh_key_fingerprint]

  tags = ["bulletin-monitoring", var.project_name]
}

locals {
  metrics_scrape_sources = coalesce(
    var.metrics_source_addresses,
    ["${digitalocean_droplet.monitoring.ipv4_address}/32"]
  )
}

resource "digitalocean_database_cluster" "postgres" {
  name       = "${var.project_name}-pg"
  engine     = "pg"
  version    = "16"
  size       = "db-s-1vcpu-1gb"
  region     = var.region
  node_count = 1

  private_network_uuid = digitalocean_vpc.main.id
}

resource "digitalocean_database_db" "bulletins" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "bulletins"
}

resource "digitalocean_database_user" "app" {
  cluster_id = digitalocean_database_cluster.postgres.id
  name       = "bulletin_app"
}

resource "digitalocean_database_firewall" "postgres" {
  cluster_id = digitalocean_database_cluster.postgres.id

  rule {
    type  = "droplet"
    value = digitalocean_droplet.app.id
  }
}

resource "digitalocean_spaces_bucket" "images" {
  name   = var.spaces_bucket_name
  region = var.region
  acl    = "private"
}

resource "digitalocean_firewall" "app" {
  name = "${var.project_name}-fw"

  droplet_ids = [digitalocean_droplet.app.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = local.metrics_scrape_sources
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "9100"
    source_addresses = local.metrics_scrape_sources
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

resource "digitalocean_firewall" "monitoring" {
  name = "${var.project_name}-monitoring-fw"

  droplet_ids = [digitalocean_droplet.monitoring.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = var.prometheus_ui_source_addresses
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "droplet_ip" {
  description = "Public IPv4 of the application server"
  value       = digitalocean_droplet.app.ipv4_address
}

output "monitoring_ip" {
  description = "Public IPv4 of the Prometheus monitoring server"
  value       = digitalocean_droplet.monitoring.ipv4_address
}

output "database_host" {
  description = "Managed PostgreSQL host (use private host from VPC when possible)"
  value       = digitalocean_database_cluster.postgres.private_host
}

output "database_port" {
  value = digitalocean_database_cluster.postgres.port
}

output "database_user" {
  value = digitalocean_database_user.app.name
}

output "database_name" {
  value = digitalocean_database_db.bulletins.name
}

output "spaces_bucket" {
  value = digitalocean_spaces_bucket.images.name
}

output "spaces_endpoint" {
  value = "https://${var.region}.digitaloceanspaces.com"
}

output "database_password" {
  description = "Managed PostgreSQL password for bulletin_app"
  value       = digitalocean_database_user.app.password
  sensitive   = true
}
