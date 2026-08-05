variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Prefix for resource names"
  type        = string
  default     = "hexlet-bulletins"
}

variable "region" {
  description = "DigitalOcean region (e.g. fra1, nyc3)"
  type        = string
  default     = "fra1"
}

variable "droplet_size" {
  description = "Droplet plan"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "ssh_key_fingerprint" {
  description = "Fingerprint of SSH key uploaded in DigitalOcean account"
  type        = string
}

variable "spaces_bucket_name" {
  description = "Globally unique Spaces bucket name"
  type        = string
}

variable "spaces_access_id" {
  description = "Spaces access key ID (DO control panel → API → Spaces access keys)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "spaces_secret_key" {
  description = "Spaces secret key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "metrics_source_addresses" {
  description = "Inbound sources for app metrics (9090, 9100, 9113). If null, only the monitoring droplet public IP /32 is allowed."
  type        = list(string)
  default     = null
}

variable "prometheus_ui_source_addresses" {
  description = "Inbound sources allowed for Prometheus UI on the monitoring droplet (9090)."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "grafana_ui_source_addresses" {
  description = "Inbound sources allowed for Grafana UI on the monitoring droplet (3000)."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}
