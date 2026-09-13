###############################################################
# Samsung Cloud Platform v2 — Monitoring and Observability Lab
###############################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    samsungcloudplatformv2 = {
      source  = "SamsungSDSCloud/samsungcloudplatformv2"
      version = "= 5.2.2"
    }
  }
}

provider "samsungcloudplatformv2" {
}

########################################
# VPC 
########################################

resource "samsungcloudplatformv2_vpc_vpc" "this" {
  name = "${var.prefix}-vpc"
  cidr = var.vpc_cidr
}

########################################
# Subnet 
########################################
resource "samsungcloudplatformv2_vpc_subnet" "web" {
  name   = "${var.prefix}-websubnet"
  vpc_id = samsungcloudplatformv2_vpc_vpc.this.id
  type   = "GENERAL"
  cidr   = var.subnet_web_cidr
  tags   = var.tags


  depends_on = [
    samsungcloudplatformv2_vpc_vpc.this,
  ]
}

resource "samsungcloudplatformv2_vpc_subnet" "app" {
  name   = "${var.prefix}-appsubnet"
  vpc_id = samsungcloudplatformv2_vpc_vpc.this.id
  type   = "GENERAL"
  cidr   = var.subnet_app_cidr
  tags   = var.tags

  depends_on = [
    samsungcloudplatformv2_vpc_vpc.this,
  ]
}

resource "samsungcloudplatformv2_vpc_subnet" "db" {
  name   = "${var.prefix}-dbsubnet"
  vpc_id = samsungcloudplatformv2_vpc_vpc.this.id
  type   = "GENERAL"
  cidr   = var.subnet_db_cidr
  tags   = var.tags

  depends_on = [
    samsungcloudplatformv2_vpc_vpc.this,
  ]
}

########################################
# Internet Gateway 
########################################
resource "samsungcloudplatformv2_vpc_internet_gateway" "this" {
  vpc_id            = samsungcloudplatformv2_vpc_vpc.this.id
  type              = "IGW"
  loggable          = var.enable_igw_logging
  firewall_enabled  = true
  firewall_loggable = var.enable_firewall_logging
  tags              = var.tags

  depends_on = [
    samsungcloudplatformv2_vpc_vpc.this,
  ]
}

########################################
# NAT Gateway
########################################
resource "samsungcloudplatformv2_vpc_publicip" "nat" {
  type = "IGW"

  depends_on = [
    samsungcloudplatformv2_vpc_internet_gateway.this,
  ]
}

resource "samsungcloudplatformv2_vpc_nat_gateway" "web" {
  subnet_id   = samsungcloudplatformv2_vpc_subnet.web.id
  publicip_id = samsungcloudplatformv2_vpc_publicip.nat.id

  depends_on = [
    samsungcloudplatformv2_vpc_internet_gateway.this,
    samsungcloudplatformv2_vpc_subnet.web,
    samsungcloudplatformv2_vpc_publicip.nat,
  ]
}

########################################
# Public IP (LB, Bastion)
########################################
# ────────────────────────────────────────────────────────────
# The LB resources below are not used. The code is kept here for reference.
#
#   Segment 1 : lab PC → straight to the Web VS public IP (does not go through the LB)
#   Segment 2 : the ingress-nginx Service is set to type: LoadBalancer so that
#               SKE automatically creates the LB, listener, server group and members.
#               The LB Terraform would create here duplicates that, so it is disabled.
#
# To bring it back, uncomment below and restore lb_public_ip in outputs.tf as well.
# ────────────────────────────────────────────────────────────
# resource "samsungcloudplatformv2_vpc_publicip" "lb" {
#   type = "IGW"
#
#   depends_on = [
#     samsungcloudplatformv2_vpc_internet_gateway.this,
#   ]
# }

# Segment 1 entry point — the lab PC connects directly to the Web VS.
resource "samsungcloudplatformv2_vpc_publicip" "web" {
  type = "IGW"

  depends_on = [
    samsungcloudplatformv2_vpc_internet_gateway.this,
  ]
}

resource "samsungcloudplatformv2_vpc_publicip" "bastion" {
  type = "IGW"

  depends_on = [
    samsungcloudplatformv2_vpc_internet_gateway.this,
  ]
}

########################################
# Security Group
########################################

resource "samsungcloudplatformv2_security_group_security_group" "web" {
  name     = "${var.prefix}-websg"
  loggable = var.enable_sg_logging
  tags     = var.tags
}

resource "samsungcloudplatformv2_security_group_security_group" "app" {
  name     = "${var.prefix}-appsg"
  loggable = var.enable_sg_logging
  tags     = var.tags
}

resource "samsungcloudplatformv2_security_group_security_group" "bastion" {
  name     = "${var.prefix}-bastionsg"
  loggable = var.enable_sg_logging
  tags     = var.tags
}

locals {
  k8s_api_port = 6443 # SKE private endpoint (…ske.private….samsungsdscloud.com:6443)
}

########################################
# Security Group Rules
########################################
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_in_from_lb" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.web_app_port
  port_range_max    = var.web_app_port
  remote_ip_prefix  = var.subnet_web_cidr
}

# Segment 1 — the lab PC connects directly to the Web VS. It does not go through
# the LB, so traffic arrives from the lab PC's public IP, not from the web subnet.
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_in_public" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.web_app_port
  port_range_max    = var.web_app_port
  remote_ip_prefix  = "${var.my_public_ip}/32"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_in_metrics" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9100
  port_range_max    = 9100
  remote_ip_prefix  = var.vpc_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_in_ssh" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.subnet_web_cidr
}

# Web VS egress — only what the Web tier actually talks to.
#   Segment 2 : Web VS → LB Service IP (SKE puts the LB in the app subnet) : app listener port
#   Internet  : dnf / nodesource / GitHub (node_exporter) over 80·443
resource "samsungcloudplatformv2_security_group_security_group_rule" "web_out_lb" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.lb_app_listener_port
  port_range_max    = var.lb_app_listener_port
  remote_ip_prefix  = var.subnet_app_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_out_http" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "web_out_https" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.web.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_in_nodeport" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.k8s_nodeport
  port_range_max    = var.k8s_nodeport
  remote_ip_prefix  = var.subnet_web_cidr
}

# Segment 2 — the inbound path into ingress-nginx.
#   Web VS → LB (app listener 3000) → the node's ingress NodePort 30000
# SKE creates the LB automatically through the ingress Service (type: LoadBalancer).
resource "samsungcloudplatformv2_security_group_security_group_rule" "app_in_ingress" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.ingress_nodeport
  port_range_max    = var.ingress_nodeport
  remote_ip_prefix  = var.vpc_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_in_lb_service" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.lb_app_listener_port
  port_range_max    = var.lb_app_listener_port
  remote_ip_prefix  = var.subnet_web_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_in_vpc" {

  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = var.subnet_app_cidr
}

# K8s node egress.
#   Segment 3 : Pod → PostgreSQL service IP : DB port
#   Node↔node : pod network / kubelet inside the app subnet
#   443       : Container Registry private endpoint (image pull), SKE managed components
#   6443      : kubelet → Kubernetes API (private endpoint — SCP-managed address, so the
#               destination cannot be narrowed to a CIDR; same convention as the SKE lab)
resource "samsungcloudplatformv2_security_group_security_group_rule" "app_out_db" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.database_port
  port_range_max    = var.database_port
  remote_ip_prefix  = "${var.postgresql_service_ip_address}/32"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_out_vpc" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = var.subnet_app_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_out_https" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "app_out_k8s_api" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.app.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = local.k8s_api_port
  port_range_max    = local.k8s_api_port
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_in_ssh" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "${var.my_public_ip}/32"
}

# Bastion egress — the lab runs from here, so it needs a few well-defined paths.
#   Web VS     : 22 (install-web.sh over SSH), app port (verification curl)
#   App subnet : 22 (--no-registry node load), LB listener port and ingress NodePort (verification)
#   DB         : psql checks in session 3
#   6443       : kubectl → Kubernetes API private endpoint (SCP-managed address)
#   80·443     : dnf, dl.k8s.io, registry.k8s.io / docker.io (podman), Container Registry private endpoint
resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_web_ssh" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "${var.web_fixed_ip}/32"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_web_app" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.web_app_port
  port_range_max    = var.web_app_port
  remote_ip_prefix  = "${var.web_fixed_ip}/32"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_app_ssh" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.subnet_app_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_lb" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.lb_app_listener_port
  port_range_max    = var.lb_app_listener_port
  remote_ip_prefix  = var.subnet_app_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_ingress_nodeport" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.ingress_nodeport
  port_range_max    = var.ingress_nodeport
  remote_ip_prefix  = var.subnet_app_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_app_nodeport" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.k8s_nodeport
  port_range_max    = var.k8s_nodeport
  remote_ip_prefix  = var.subnet_app_cidr
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_db" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.database_port
  port_range_max    = var.database_port
  remote_ip_prefix  = "${var.postgresql_service_ip_address}/32"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_k8s_api" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = local.k8s_api_port
  port_range_max    = local.k8s_api_port
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_http" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "samsungcloudplatformv2_security_group_security_group_rule" "bastion_out_https" {
  security_group_id = samsungcloudplatformv2_security_group_security_group.bastion.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

########################################
# Firewall Rules
########################################
data "samsungcloudplatformv2_firewall_firewalls" "igw" {
  product_type = ["IGW"]
  vpc_name     = samsungcloudplatformv2_vpc_vpc.this.name
  size         = 1

  depends_on = [samsungcloudplatformv2_vpc_internet_gateway.this]
}

locals {
  igw_firewall_id = try(data.samsungcloudplatformv2_firewall_firewalls.igw.ids[0], "")
}

# Segment 1 — lab PC → straight to the Web Virtual Server (does not go through the LB)
#
# Previously the destination was the whole web subnet and the port was the LB web listener (80).
# Since the LB is no longer used, only port 3000 on the single Web VS is opened.
resource "samsungcloudplatformv2_firewall_firewall_rule" "allow_web_in" {
  firewall_id = local.igw_firewall_id

  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    source_address      = ["${var.my_public_ip}/32"]
    destination_address = [var.web_fixed_ip]
    status              = "ENABLE"
    service = [{
      service_type  = "TCP"
      service_value = tostring(var.web_app_port)
    }]
  }

  depends_on = [
    samsungcloudplatformv2_vpc_internet_gateway.this,
  ]
}

resource "samsungcloudplatformv2_firewall_firewall_rule" "allow_bastion_ssh" {
  firewall_id = local.igw_firewall_id

  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "INBOUND"
    source_address      = ["${var.my_public_ip}/32"]
    destination_address = [var.bastion_fixed_ip]
    status              = "ENABLE"
    service = [{
      service_type  = "TCP"
      service_value = "22"
    }]
  }

  depends_on = [
    samsungcloudplatformv2_vpc_internet_gateway.this,
    samsungcloudplatformv2_firewall_firewall_rule.allow_web_in,
  ]
}

# Internet egress through the IGW — only the two hosts that need it, only 80·443.
#   Web VS  : dnf / nodesource / GitHub (node_exporter)
#   Bastion : dnf / dl.k8s.io / registry.k8s.io / docker.io
# K8s nodes and the DB subnet never leave the VPC through the IGW; the app subnet has no NAT.
resource "samsungcloudplatformv2_firewall_firewall_rule" "allow_out" {
  firewall_id = local.igw_firewall_id

  firewall_rule_create = {
    action              = "ALLOW"
    direction           = "OUTBOUND"
    source_address      = [var.web_fixed_ip, var.bastion_fixed_ip]
    destination_address = ["0.0.0.0/0"]
    status              = "ENABLE"
    service = [
      {
        service_type  = "TCP"
        service_value = "80"
      },
      {
        service_type  = "TCP"
        service_value = "443"
      },
    ]
  }

  depends_on = [
    samsungcloudplatformv2_vpc_internet_gateway.this,
    samsungcloudplatformv2_firewall_firewall_rule.allow_bastion_ssh,
  ]
}

########################################
# Keypair
########################################

resource "samsungcloudplatformv2_virtualserver_keypair" "kp" {
  name = var.keypair_name
  tags = var.tags
}

########################################
# Virtual Server — Web, Bastion
########################################

data "samsungcloudplatformv2_virtualserver_images" "os" {
  scp_image_type = "STANDARD"
  os_distro      = var.image_os_distro
  status         = "active"

  filter {
    name      = "name"
    values    = [var.image_name_pattern]
    use_regex = true
  }
}

locals {
  image_ids = data.samsungcloudplatformv2_virtualserver_images.os.ids != null ? data.samsungcloudplatformv2_virtualserver_images.os.ids : []
  image_id  = var.server_image_id != "" ? var.server_image_id : (length(local.image_ids) > 0 ? local.image_ids[0] : "")

  bootstrap = <<-EOT
    #!/usr/bin/env bash
    set -eux
    if command -v apt-get >/dev/null 2>&1; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
      apt-get install -y nodejs curl
    else
      # On Rocky 9 curl-minimal is the default, so installing curl alongside it conflicts
      curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
      dnf install -y nodejs || yum install -y nodejs
    fi
    mkdir -p /opt/logapp /var/log/logapp
    node --version > /var/log/logapp/bootstrap.log 2>&1
  EOT

  # The Bastion gets additional lab tools.
  #   kubectl : the K8s API is a private endpoint, reachable only from the Bastion
  #   jq      : used in session 2 to inspect JSON logs
  #   git     : downloading the course material
  bootstrap_bastion = <<-EOT
    ${local.bootstrap}
    # kubectl — matched to the same minor version as the cluster.
    # The patch version SCP reports may not exist upstream, so try the exact
    # patch first and fall back to the latest patch of the same minor on failure.
    KVER="${var.kubernetes_version}"
    if ! curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl"; then
      MINOR=$(echo "$${KVER#v}" | cut -d. -f1,2)
      KVER=$(curl -fsSL "https://dl.k8s.io/release/stable-$MINOR.txt")
      curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/$KVER/bin/linux/amd64/kubectl"
    fi
    chmod 0755 /usr/local/bin/kubectl
    /usr/local/bin/kubectl version --client >> /var/log/logapp/bootstrap.log 2>&1

    # Helper tools
    dnf install -y jq git >> /var/log/logapp/bootstrap.log 2>&1 || true

    # Container image build/push tools
    # The API tier image is built on the Bastion and pushed to the Container Registry.
    # Rocky 9 has no docker, so install podman together with the docker command shim.
    dnf install -y podman podman-docker >> /var/log/logapp/bootstrap.log 2>&1 || true
    mkdir -p /etc/containers && touch /etc/containers/nodocker
    podman --version >> /var/log/logapp/bootstrap.log 2>&1 || true

    # kubectl autocompletion
    echo 'source <(kubectl completion bash)' >> /home/rocky/.bashrc
  EOT
}

resource "samsungcloudplatformv2_virtualserver_server" "web" {
  name           = "${var.prefix}web"
  state          = "ACTIVE"
  zone           = var.zone
  image_id       = local.image_id
  server_type_id = var.server_type_id
  keypair_name   = samsungcloudplatformv2_virtualserver_keypair.kp.name
  user_data      = base64encode(local.bootstrap)

  boot_volume = {
    size                  = 32
    type                  = "SSD"
    delete_on_termination = true
  }

  networks = {
    nic0 = {
      subnet_id    = samsungcloudplatformv2_vpc_subnet.web.id
      fixed_ip     = var.web_fixed_ip
      public_ip_id = samsungcloudplatformv2_vpc_publicip.web.id
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.web.id]
  tags            = merge(var.tags, { tier = "web" })

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.web,
    samsungcloudplatformv2_security_group_security_group.web,
    samsungcloudplatformv2_virtualserver_keypair.kp,
    samsungcloudplatformv2_vpc_publicip.web,
  ]
}

resource "samsungcloudplatformv2_virtualserver_server" "bastion" {
  name           = "${var.prefix}bastion"
  state          = "ACTIVE"
  zone           = var.zone
  image_id       = local.image_id
  server_type_id = coalesce(var.bastion_server_type_id, var.server_type_id)
  keypair_name   = samsungcloudplatformv2_virtualserver_keypair.kp.name
  user_data      = base64encode(local.bootstrap_bastion)

  boot_volume = {
    size                  = 32
    type                  = "SSD"
    delete_on_termination = true
  }

  networks = {
    nic0 = {
      subnet_id    = samsungcloudplatformv2_vpc_subnet.web.id
      fixed_ip     = var.bastion_fixed_ip
      public_ip_id = samsungcloudplatformv2_vpc_publicip.bastion.id
    }
  }

  security_groups = [samsungcloudplatformv2_security_group_security_group.bastion.id]
  tags            = merge(var.tags, { tier = "bastion" })

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.web,
    samsungcloudplatformv2_security_group_security_group.bastion,
    samsungcloudplatformv2_virtualserver_keypair.kp,
    samsungcloudplatformv2_vpc_publicip.bastion,
  ]
}

########################################
# Load Balancer
########################################

# resource "samsungcloudplatformv2_loadbalancer_loadbalancer" "this" {
#   loadbalancer_create = {
#     name                     = "${var.prefix}lb"
#     vpc_id                   = samsungcloudplatformv2_vpc_vpc.this.id
#     subnet_id                = samsungcloudplatformv2_vpc_subnet.web.id
#     layer_type               = "L7"
#     firewall_enabled         = true
#     firewall_logging_enabled = var.enable_lb_firewall_logging
#
#     service_ip        = var.lb_service_ip
#     source_nat_ip     = null
#     health_check_ip_1 = null
#     health_check_ip_2 = null
#   }
#
#   depends_on = [
#     samsungcloudplatformv2_vpc_internet_gateway.this,
#     samsungcloudplatformv2_vpc_subnet.web,
#   ]
# }

# resource "samsungcloudplatformv2_loadbalancer_loadbalancer_public_nat_ip" "this" {
#   loadbalancer_id = samsungcloudplatformv2_loadbalancer_loadbalancer.this.id
#
#   static_nat_create = {
#     publicip_id = samsungcloudplatformv2_vpc_publicip.lb.id
#   }
#
#   depends_on = [
#     samsungcloudplatformv2_vpc_internet_gateway.this,
#     samsungcloudplatformv2_loadbalancer_loadbalancer.this,
#     samsungcloudplatformv2_vpc_publicip.lb,
#   ]
# }

########################################
# File Storage
########################################

resource "samsungcloudplatformv2_filestorage_volume" "this" {
  access_rules = []

  name      = "${var.prefix}fs"
  protocol  = "NFS"
  type_name = "HDD"
  zone      = var.zone
  tags      = var.tags
}

########################################
# Container(Kubernetes Engine)
########################################

data "samsungcloudplatformv2_ske_nodepool_images" "k8s" {
  scp_original_image_type = "k8s"
  kubernetes_version      = var.kubernetes_version
}

locals {
  nodepool_image_candidates = [
    for i in try(data.samsungcloudplatformv2_ske_nodepool_images.k8s.nodepool_images, []) : i
    if i.os == var.nodepool_image_os && i.end_of_support == false
  ]

  nodepool_image_os_version = (
    var.nodepool_image_os_version != "" ?
    var.nodepool_image_os_version :
    (length(local.nodepool_image_candidates) > 0 ? local.nodepool_image_candidates[0].os_version : "")
  )
}

resource "samsungcloudplatformv2_ske_cluster" "this" {

  service_watch_logging_enabled = false
  name                          = "${var.prefix}-ske"
  kubernetes_version            = var.kubernetes_version
  vpc_id                        = samsungcloudplatformv2_vpc_vpc.this.id
  subnet_id                     = samsungcloudplatformv2_vpc_subnet.app.id
  security_group_id_list        = [samsungcloudplatformv2_security_group_security_group.app.id]

  volume_id = samsungcloudplatformv2_filestorage_volume.this.id

  cloud_logging_enabled = false

  private_endpoint_access_control_resources = [
    {
      id   = samsungcloudplatformv2_virtualserver_server.bastion.id
      name = samsungcloudplatformv2_virtualserver_server.bastion.name
      type = "vm"
    }
  ]

  tags = merge(var.tags, { tier = "app" })


  depends_on = [
    samsungcloudplatformv2_vpc_subnet.app,
    samsungcloudplatformv2_security_group_security_group.app,
    samsungcloudplatformv2_filestorage_volume.this,
    samsungcloudplatformv2_virtualserver_server.bastion,
  ]
}

resource "samsungcloudplatformv2_ske_nodepool" "this" {
  name       = "${var.prefix}-np"
  cluster_id = samsungcloudplatformv2_ske_cluster.this.id
  subnet_id  = samsungcloudplatformv2_vpc_subnet.app.id

  kubernetes_version = var.kubernetes_version
  image_os           = var.nodepool_image_os
  image_os_version   = local.nodepool_image_os_version
  server_type_id     = var.nodepool_server_type_id
  keypair_name       = samsungcloudplatformv2_virtualserver_keypair.kp.name

  desired_node_count = var.nodepool_node_count
  min_node_count     = var.nodepool_node_count
  max_node_count     = var.nodepool_node_count

  is_auto_scale    = false
  is_auto_recovery = true

  volume_type_name = "SSD"
  volume_size      = 104
  zone             = var.zone

  depends_on = [
    samsungcloudplatformv2_ske_cluster.this,
    samsungcloudplatformv2_vpc_subnet.app,
  ]
}

########################################
# PostgreSQL(DBaaS)
########################################

data "samsungcloudplatformv2_postgresql_engine_version" "pg" {}

locals {
  pg_engine_versions = data.samsungcloudplatformv2_postgresql_engine_version.pg.contents != null ? data.samsungcloudplatformv2_postgresql_engine_version.pg.contents : []

  pg_engine_candidates = [
    for v in local.pg_engine_versions : v
    if v.end_of_service == false && can(regex(var.postgresql_version_pattern, v.software_version))
  ]

  pg_engine_version_id = (
    var.postgresql_engine_version_id != "" ?
    var.postgresql_engine_version_id :
    (length(local.pg_engine_candidates) > 0 ? local.pg_engine_candidates[0].id : "")
  )
}

resource "samsungcloudplatformv2_postgresql_cluster" "this" {
  name                    = replace("${var.prefix}pgcluster", "/[^a-zA-Z]/", "")
  instance_name_prefix    = replace("${var.prefix}pg", "/[^a-zA-Z]/", "")
  dbaas_engine_version_id = local.pg_engine_version_id
  subnet_id               = samsungcloudplatformv2_vpc_subnet.db.id
  service_state           = "RUNNING"
  timezone                = var.database_timezone

  ha_enabled  = false
  nat_enabled = false

  allowable_ip_addresses = [var.subnet_app_cidr]

  init_config_option = {

    audit_enabled          = true
    database_encoding      = "UTF-8"
    database_locale        = "C"
    database_name          = var.db_name
    database_port          = var.database_port
    database_user_name     = var.db_user
    database_user_password = var.db_password

    backup_option = {
      retention_period_day     = var.database_backup_option.retention_period_day
      starting_time_hour       = var.database_backup_option.starting_time_hour
      archive_frequency_minute = var.database_backup_option.archive_frequency_minute
    }
  }

  instance_groups = [
    {
      role_type        = "ACTIVE"
      server_type_name = var.postgresql_server_type_name

      block_storage_groups = [
        {
          role_type   = "OS"
          volume_type = "SSD"
          size_gb     = 104
        },
        {
          role_type   = "DATA"
          volume_type = "SSD"
          size_gb     = var.postgresql_data_size_gb
        }
      ]

      instances = [
        {
          role_type          = "ACTIVE"
          service_ip_address = var.postgresql_service_ip_address
        }
      ]
    }
  ]

  maintenance_option = {
    use_maintenance_option = false
    period_hour            = null
    starting_day_of_week   = null
    starting_time          = null
  }

  tags = merge(var.tags, { tier = "db" })

  depends_on = [
    samsungcloudplatformv2_vpc_subnet.db,
  ]
}

