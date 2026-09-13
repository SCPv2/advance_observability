########################################
# Common
########################################

variable "prefix" {
  type    = string
  default = "ce"
}

variable "zone" {
  type    = string
  default = "kr-west1-b"
}

variable "keypair_name" {
  type    = string
  default = "mykey"
}

variable "my_public_ip" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {
    env    = "lab"
    course = "advance-observability"
  }
}

########################################
# Network
########################################

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "subnet_web_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "subnet_app_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "subnet_db_cidr" {
  type    = string
  default = "10.10.3.0/24"
}

########################################
# Compute
########################################

variable "server_image_id" {
  type    = string
  default = ""
}

variable "image_os_distro" {
  type    = string
  default = "Rocky"
}

variable "image_name_pattern" {
  type    = string
  default = "Rocky 9.6"
}

variable "web_fixed_ip" {
  type    = string
  default = "10.10.1.11"
}

variable "bastion_fixed_ip" {
  type    = string
  default = "10.10.1.12"
}

variable "lb_service_ip" {
  type    = string
  default = "10.10.1.100"
}

variable "server_type_id" {
  type    = string
  default = "s1v1m2"
}

variable "bastion_server_type_id" {
  type    = string
  default = null
}

########################################
# Container (Kubernetes Engine)
########################################

variable "kubernetes_version" {
  type    = string
  default = "v1.35.5"
}

variable "nodepool_server_type_id" {
  type    = string
  default = "s1v2m4"
}

variable "nodepool_node_count" {
  type    = number
  default = 2
}

variable "nodepool_image_os" {
  type    = string
  default = "ubuntu"
}

variable "nodepool_image_os_version" {
  type    = string
  default = ""
}

variable "k8s_node_ips" {
  type    = list(string)
  default = []
}

########################################
# PostgreSQL(DBaaS)
########################################

variable "postgresql_engine_version_id" {
  type    = string
  default = ""
}

variable "postgresql_server_type_name" {
  type    = string
  default = "db1v2m4"
}

variable "postgresql_data_size_gb" {
  type    = number
  default = 16
}

variable "db_name" {
  type    = string
  default = "cedb"
}

variable "db_user" {
  type    = string
  default = "labuser"
}

# Fixed password for the lab. It can be overridden with the TF_VAR_db_password environment variable.
# For the lab environment only; in a real production environment do not set a default.
variable "db_password" {
  type      = string
  sensitive = true
  default   = "StrongPassword1!"
}

variable "postgresql_version_pattern" {
  type    = string
  default = "COMMUNITY 16"
}

variable "postgresql_service_ip_address" {
  type    = string
  default = "10.10.3.31"
}

variable "database_port" {
  type    = number
  default = 2866
}

variable "database_timezone" {
  type    = string
  default = "Asia/Seoul"
}

variable "database_backup_option" {
  type = object({
    retention_period_day     = string
    starting_time_hour       = string
    archive_frequency_minute = string
  })
  default = {
    retention_period_day     = "7"
    starting_time_hour       = "12"
    archive_frequency_minute = "60"
  }
}

########################################
# Load Balancer / Ingress
#
# Terraform does not create the LB itself (it is commented out in main.tf).
#   Segment 1 : lab PC → straight to the Web VS public IP
#   Segment 2 : ingress-nginx Service (type: LoadBalancer) → SKE creates the LB automatically
# The port values below are used by the firewall and SG rules and by the ingress Service config.
########################################

# Used only when bringing the LB back (currently unused)
variable "lb_web_listener_port" {
  type    = number
  default = 80
}

# LB listener port for Segment 2. It must match the port of the ingress Service.
variable "lb_app_listener_port" {
  type    = number
  default = 3000
}

# NodePort of the ingress-nginx Service. The LB forwards to this port on the nodes.
variable "ingress_nodeport" {
  type    = number
  default = 30000
}

variable "web_app_port" {
  type    = number
  default = 3000
}

variable "k8s_nodeport" {
  type    = number
  default = 30080
}

########################################
# Observability Options
########################################

variable "enable_igw_logging" {
  type    = bool
  default = false
}

variable "enable_firewall_logging" {
  type    = bool
  default = false
}

variable "enable_sg_logging" {
  type    = bool
  default = false
}

variable "enable_lb_firewall_logging" {
  type    = bool
  default = false
}
