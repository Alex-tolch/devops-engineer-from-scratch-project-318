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
