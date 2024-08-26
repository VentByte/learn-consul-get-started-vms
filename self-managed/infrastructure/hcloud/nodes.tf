#------------------------------------------------------------------------------#
## Bastion host
#------------------------------------------------------------------------------#
locals {
  workdir = "/root/"

  node_defaults = {
    image       = "debian-12"
    location    = "fsn1"
    ssh_keys    = [hcloud_ssh_key.default.id]
    server_type = "cx22"

    labels = {
      tag      = "learn-consul"
      scenario = var.scenario
    }

    ipv4_enabled = true
    ipv6_enabled = false

    connection_type = "ssh"
    connection_user = "root"
  }

  bastion_fake_dns = <<-EOT
    # The following lines are added for hashicups scenario
    ${hcloud_server_network.nginx.ip} hashicups-nginx nginx
    ${hcloud_server_network.frontend.ip} hashicups-frontend frontend
    ${hcloud_server_network.api.ip} hashicups-api api
    ${hcloud_server_network.database.ip} hashicups-db database db
    ${hcloud_server_network.consul_server.0.ip} consul server.${var.consul_datacenter}.${var.consul_domain}
    %{for index, ip in hcloud_server_network.consul_server.*.ip~}
    ${ip} consul-server-${index} 
    %{endfor~}
    ${hcloud_server_network.gateway-api.ip} gateway-api gw-api
    ${hcloud_server.gateway-api.ipv4_address} gateway-api-public gw-api-public
  EOT
}

resource "hcloud_server" "bastion" {
  name        = "bastion"
  image       = local.node_defaults.image
  location    = local.node_defaults.location
  ssh_keys    = local.node_defaults.ssh_keys
  server_type = local.node_defaults.server_type
  labels = merge(local.node_defaults.labels, {
    app  = "openSSH"
    role = "bastion"
  })

  public_net {
    ipv4_enabled = local.node_defaults.ipv4_enabled
    ipv6_enabled = local.node_defaults.ipv6_enabled
  }

  firewall_ids = [
    hcloud_firewall.ingress-ssh.id,
    hcloud_firewall.ingress-monitoring-suite.id
  ]

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_bastion.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "bastion",
    consul_version  = "${var.consul_version}",
    # HOSTS_EXTRA_CONFIG = base64gzip("${data.template_file.dns_extra_conf.rendered}")
    HOSTS_EXTRA_CONFIG = base64gzip("${local.bastion_fake_dns}")
  })

  connection {
    type        = local.node_defaults.connection_type
    user        = local.node_defaults.connection_user
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.ipv4_address
  }

  # file, local-exec, remote-exec
  # Copy monitoring suite config files
  provisioner "file" {
    source      = "${path.module}/../../../assets"
    destination = local.workdir
  }

  provisioner "file" {
    source      = "${path.module}/../../ops"
    destination = local.workdir
  }
}

resource "hcloud_server_network" "bastion" {
  server_id = hcloud_server.bastion.id
  subnet_id = hcloud_network_subnet.public[0].id
}

#------------------------------------------------------------------------------#
## Consul Server(s)
#------------------------------------------------------------------------------#
resource "hcloud_server" "consul_server" {
  count = var.server_number

  name        = "consul-server-${count.index}"
  image       = local.node_defaults.image
  location    = local.node_defaults.location
  ssh_keys    = local.node_defaults.ssh_keys
  server_type = local.node_defaults.server_type
  labels = merge(local.node_defaults.labels, {
    app  = "consul"
    role = "control-plane"
  })

  public_net {
    ipv4_enabled = local.node_defaults.ipv4_enabled
    ipv6_enabled = local.node_defaults.ipv6_enabled
  }

  firewall_ids = [
    hcloud_firewall.ingress-ssh.id,
    hcloud_firewall.consul-agents.id,
    hcloud_firewall.consul-servers.id
  ]

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "consul-server-${count.index}",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = local.node_defaults.connection_type
    user        = local.node_defaults.connection_user
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.ipv4_address
  }

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null"
    ]
  }
}

resource "hcloud_server_network" "consul_server" {
  # for_each  = var.server_number
  count     = var.server_number
  server_id = hcloud_server.consul_server[count.index].id
  subnet_id = hcloud_network_subnet.public[0].id
}

#------------------------------------------------------------------------------#
## HashiCups
#------------------------------------------------------------------------------#

#------------#
#  DATABASE  #
#------------#
resource "hcloud_server" "database" {
  name        = "hashicups-db"
  image       = local.node_defaults.image
  location    = local.node_defaults.location
  ssh_keys    = local.node_defaults.ssh_keys
  server_type = local.node_defaults.server_type
  labels = merge(local.node_defaults.labels, {
    app  = "hashicups"
    role = "data-plane"
  })

  public_net {
    ipv4_enabled = local.node_defaults.ipv4_enabled
    ipv6_enabled = local.node_defaults.ipv6_enabled
  }

  firewall_ids = [
    hcloud_firewall.ingress-ssh.id,
    hcloud_firewall.ingress-db.id,
    hcloud_firewall.consul-agents.id,
    hcloud_firewall.ingress-envoy.id
  ]

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-db",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = local.node_defaults.connection_type
    user        = local.node_defaults.connection_user
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.ipv4_address
  }

  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
    destination = "${local.workdir}/install_envoy.sh" # remote machine
  }
}

resource "hcloud_server_network" "database" {
  server_id = hcloud_server.database.id
  subnet_id = hcloud_network_subnet.public[0].id
}

#------------#
#    API     #
#------------#
resource "hcloud_server" "api" {
  name        = "hashicups-api"
  image       = local.node_defaults.image
  location    = local.node_defaults.location
  ssh_keys    = local.node_defaults.ssh_keys
  server_type = local.node_defaults.server_type
  labels = merge(local.node_defaults.labels, {
    app  = "hashicups"
    role = "data-plane"
  })

  public_net {
    ipv4_enabled = local.node_defaults.ipv4_enabled
    ipv6_enabled = local.node_defaults.ipv6_enabled
  }

  firewall_ids = [
    hcloud_firewall.ingress-ssh.id,
    hcloud_firewall.ingress-api.id,
    hcloud_firewall.consul-agents.id,
    hcloud_firewall.ingress-envoy.id
  ]

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-api",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = local.node_defaults.connection_type
    user        = local.node_defaults.connection_user
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.ipv4_address
  }

  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
    destination = "${local.workdir}/install_envoy.sh" # remote machine
  }
}

resource "hcloud_server_network" "api" {
  server_id = hcloud_server.api.id
  subnet_id = hcloud_network_subnet.public[0].id
}

#------------#
#  FRONTEND  #
#------------#
resource "hcloud_server" "frontend" {
  name        = "hashicups-frontend"
  image       = local.node_defaults.image
  location    = local.node_defaults.location
  ssh_keys    = local.node_defaults.ssh_keys
  server_type = local.node_defaults.server_type
  labels = merge(local.node_defaults.labels, {
    app  = "hashicups"
    role = "data-plane"
  })

  public_net {
    ipv4_enabled = local.node_defaults.ipv4_enabled
    ipv6_enabled = local.node_defaults.ipv6_enabled
  }

  firewall_ids = [
    hcloud_firewall.ingress-ssh.id,
    hcloud_firewall.ingress-fe.id,
    hcloud_firewall.consul-agents.id,
    hcloud_firewall.ingress-envoy.id
  ]

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-frontend",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = local.node_defaults.connection_type
    user        = local.node_defaults.connection_user
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.ipv4_address
  }

  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
    destination = "${local.workdir}/install_envoy.sh" # remote machine
  }
}

resource "hcloud_server_network" "frontend" {
  server_id = hcloud_server.frontend.id
  subnet_id = hcloud_network_subnet.public[0].id
}

#------------#
#   NGINX    #
#------------#
resource "hcloud_server" "nginx" {
  name        = "hashicups-nginx"
  image       = local.node_defaults.image
  location    = local.node_defaults.location
  ssh_keys    = local.node_defaults.ssh_keys
  server_type = local.node_defaults.server_type
  labels = merge(local.node_defaults.labels, {
    app  = "hashicups"
    role = "data-plane"
  })

  public_net {
    ipv4_enabled = local.node_defaults.ipv4_enabled
    ipv6_enabled = local.node_defaults.ipv6_enabled
  }

  firewall_ids = [
    hcloud_firewall.ingress-ssh.id,
    hcloud_firewall.ingress-web.id,
    hcloud_firewall.consul-agents.id,
    hcloud_firewall.ingress-envoy.id
  ]

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-nginx",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = local.node_defaults.connection_type
    user        = local.node_defaults.connection_user
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.ipv4_address
  }

  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
    destination = "${local.workdir}/install_envoy.sh" # remote machine
  }
}

resource "hcloud_server_network" "nginx" {
  server_id = hcloud_server.nginx.id
  subnet_id = hcloud_network_subnet.public[0].id
}

#------------#
#  API GW    #
#------------#
resource "hcloud_server" "gateway-api" {
  name        = "gateway-api"
  image       = local.node_defaults.image
  location    = local.node_defaults.location
  ssh_keys    = local.node_defaults.ssh_keys
  server_type = local.node_defaults.server_type
  labels = merge(local.node_defaults.labels, {
    app  = "hashicups"
    role = "data-plane"
  })

  public_net {
    ipv4_enabled = local.node_defaults.ipv4_enabled
    ipv6_enabled = local.node_defaults.ipv6_enabled
  }

  firewall_ids = [
    hcloud_firewall.ingress-ssh.id,
    hcloud_firewall.ingress-gw-api.id,
    hcloud_firewall.consul-agents.id,
    hcloud_firewall.ingress-envoy.id
  ]

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "gateway-api",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = local.node_defaults.connection_type
    user        = local.node_defaults.connection_user
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.ipv4_address
  }

  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
    destination = "${local.workdir}/install_envoy.sh" # remote machine
  }
}

resource "hcloud_server_network" "gateway-api" {
  server_id = hcloud_server.gateway-api.id
  subnet_id = hcloud_network_subnet.public[0].id
}

