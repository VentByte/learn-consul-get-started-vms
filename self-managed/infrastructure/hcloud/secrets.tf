resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  name = "${var.prefix}-${random_string.suffix.result}"
}

#------------------------------------------------------------------------------#
# Key/Cert for SSH connection to the hosts
#------------------------------------------------------------------------------#
resource "tls_private_key" "keypair_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "default" {
  name       = "id_rsa.pub.${local.name}"
  public_key = tls_private_key.keypair_private_key.public_key_openssh

  # Create "id_rsa.pem" in local directory
  provisioner "local-exec" {
    command = "rm -rf certs/id_rsa.pem && mkdir -p certs &&  echo '${tls_private_key.keypair_private_key.private_key_pem}' > certs/id_rsa.pem && chmod 400 certs/id_rsa.pem"
  }
}