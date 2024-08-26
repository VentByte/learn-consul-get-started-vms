#------------------------------------------------------------------------------#
## Config Files for scenario
#------------------------------------------------------------------------------#

#------------------------------------------------------------------------------#
## Scenario Environment Variables
#------------------------------------------------------------------------------#

resource "local_file" "scenario_env" {
  content = templatefile("${path.module}/../../../assets/templates/provision/scenario_env.env.tmpl", {
    consul_datacenter = var.consul_datacenter,
    consul_domain     = var.consul_domain,
    server_number     = var.server_number,
    retry_join        = var.retry_join,
    cloud_provider    = "hcloud",
    log_level         = var.log_level
  })
  filename = "${path.module}/../../../assets/scenario/scenario_env.env"
}

#------------------------------------------------------------------------------#
## HashiCups Application Starting Scripts
#------------------------------------------------------------------------------#
resource "local_file" "start_hashicups_db" {
  content = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_db.sh.tmpl", {
    VERSION                = var.db_version
    CONFIGURE_SERVICE_MESH = var.config_services_for_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_db.sh"
}

resource "local_file" "start_hashicups_api" {
  content = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_api.sh.tmpl", {
    VERSION_PAY            = var.api_payments_version,
    VERSION_PROD           = var.api_product_version,
    VERSION_PUB            = var.api_public_version,
    DB_HOST                = var.config_services_for_mesh ? "localhost" : hcloud_server_network.database.ip,
    PRODUCT_API_HOST       = "localhost",
    PAYMENT_API_HOST       = "localhost",
    CONFIGURE_SERVICE_MESH = var.config_services_for_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_api.sh"
}

resource "local_file" "start_hashicups_fe" {
  content = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_fe.sh.tmpl", {
    VERSION                = var.fe_version,
    API_HOST               = var.config_services_for_mesh ? "localhost" : hcloud_server_network.api.ip,
    CONFIGURE_SERVICE_MESH = var.config_services_for_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_fe.sh"
}

resource "local_file" "start_hashicups_nginx" {
  content = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_nginx.sh.tmpl", {
    PUBLIC_API_HOST        = var.config_services_for_mesh ? "localhost" : hcloud_server_network.api.ip
    FE_HOST                = var.config_services_for_mesh ? "localhost" : hcloud_server_network.frontend.ip
    CONFIGURE_SERVICE_MESH = var.config_services_for_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_nginx.sh"
}

#------------------------------------------------------------------------------#
## Grafana monitoring suite starting script
#------------------------------------------------------------------------------#

resource "local_file" "start_monitoring_suite" {
  content  = templatefile("${path.module}/../../../assets/templates/provision/start_monitoring_suite.sh.tmpl", {})
  filename = "${path.module}/../../../assets/scenario/start_monitoring_suite.sh"
}
