// A variable for extracting the external ip of the instance
output "ip_bastion" {
  value = hcloud_server.bastion.ipv4_address
}

output "connection_string" {
  value = "ssh -i certs/id_rsa.pem ${local.node_defaults.connection_user}@`terraform output -raw ip_bastion`"
}

output "ui_consul" {
  value = "https://${hcloud_server.consul_server[0].ipv4_address}:8443"
}

output "ui_grafana" {
  value = "http://${hcloud_server.bastion.ipv4_address}:3000/d/hashicups/hashicups"
}

output "remote_ops" {
  value = "export BASTION_HOST=${hcloud_server.bastion.ipv4_address}"
}

# output "retry_join" {
#   value = local.retry_join
# }
