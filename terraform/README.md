# Terraform (DigitalOcean)

VPC, Droplet, Managed PostgreSQL, Spaces bucket, firewall.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
terraform destroy
```

Spaces credentials go in `ansible/group_vars/app/vault.yml`.
