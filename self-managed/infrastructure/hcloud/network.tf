#------------------------------------------------------------------------------#
# Private Network and Subnets
#------------------------------------------------------------------------------#
locals {
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

resource "hcloud_network" "main" {
  name     = "learn-consul-network"
  ip_range = "10.0.0.0/16"
  labels = {
    label = "tag"
    value = "learn-consul"
  }
}

resource "hcloud_network_subnet" "public" {
  # for_each     = local.public_subnets
  count        = length(local.public_subnets)
  network_id   = hcloud_network.main.id
  network_zone = var.network_region
  type         = "cloud"
  ip_range     = local.public_subnets[count.index]
}

resource "hcloud_network_subnet" "private" {
  # for_each     = local.private_subnets
  count        = length(local.private_subnets)
  network_id   = hcloud_network.main.id
  network_zone = var.network_region
  type         = "cloud"
  ip_range     = local.private_subnets[count.index]
}

#------------------------------------------------------------------------------#
# Firewall rules
#------------------------------------------------------------------------------#
resource "hcloud_firewall" "ingress-ssh" {
  name = "allow-all-sg"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "ingress-web" {
  name = "allow-web-sg"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "ingress-db" {
  name = "allow-db-sg"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "5432"
    source_ips = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "ingress-api" {
  name = "allow-api-sg"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8081"
    source_ips = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "ingress-fe" {
  name = "allow-fe-sg"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "3000"
    source_ips = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "consul-agents" {
  name = "allow-consul-agents-sg"

  rule {
    description = "allow_serf_lan_tcp_inbound"
    direction   = "in"
    protocol    = "tcp"
    port        = "8301"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "allow_serf_lan_udp_inbound"
    direction   = "in"
    protocol    = "udp"
    port        = "8301"
    source_ips  = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "consul-servers" {
  name = "allow-consul-servers-sg"

  rule {
    description = "allow_server_rcp_tcp_inbound"
    direction   = "in"
    protocol    = "tcp"
    port        = "8300"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "allow_server_http_and_grpc_inbound - HTTP:8500 | HTTPS:8501 | GRPC:8502 | GRPCS:8503"
    direction   = "in"
    protocol    = "tcp"
    port        = "8500-8503"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8443"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    description = "allow_serf_wan_tcp_inbound"
    direction   = "in"
    protocol    = "tcp"
    port        = "8302"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "allow_serf_wan_udp_inbound"
    direction   = "in"
    protocol    = "udp"
    port        = "8302"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "allow_dns_tcp_inbound"
    direction   = "in"
    protocol    = "tcp"
    port        = "8600"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "allow_dns_udp_inbound"
    direction   = "in"
    protocol    = "udp"
    port        = "8600"
    source_ips  = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "ingress-monitoring-suite" {
  name = "allow-monitoring-suite-sg"

  rule {
    description = "Allow Grafana Access"
    direction   = "in"
    protocol    = "tcp"
    port        = "3000"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "Allow Mimir Access"
    direction   = "in"
    protocol    = "tcp"
    port        = "9009"
    source_ips  = ["0.0.0.0/0"]
  }

  rule {
    description = "Allow Loki Access"
    direction   = "in"
    protocol    = "tcp"
    port        = "3100"
    source_ips  = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "ingress-envoy" {
  name = "allow-envoy-sg"

  rule {
    description = "Allow Grafana Access"
    direction   = "in"
    protocol    = "tcp"
    port        = "21000"
    source_ips  = ["0.0.0.0/0"]
  }
}

resource "hcloud_firewall" "ingress-gw-api" {
  name = "allow-api-gw-sg"

  rule {
    description = "Allow Grafana Access"
    direction   = "in"
    protocol    = "tcp"
    port        = "8443"
    source_ips  = ["0.0.0.0/0"]
  }
}
