########################################
# Values needed after the deploy
#
# These values are used in the manual steps at the end of Lab 1-1 in session 1.
########################################

# Segment 1 entry point — the lab PC connects directly to this address.
output "web_public_ip" {
  value = samsungcloudplatformv2_vpc_publicip.web.publicip.ip_address
}

output "web_server_ip" {
  value = var.web_fixed_ip
}

output "web_app_port" {
  value = var.web_app_port
}

# Segment 2 entry point — once the ingress-nginx Service (type: LoadBalancer) is created,
# SKE creates the LB and its service IP lands here. Terraform does not know this value,
# so check it with kubectl from the Bastion.
#   kubectl -n ingress-nginx get svc ingress-nginx-controller
output "ingress_lb_hint" {
  value = "kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

# Uncomment these together when bringing the LB back.
# output "lb_public_ip" {
#   value = samsungcloudplatformv2_vpc_publicip.lb.publicip.ip_address
# }
#
# output "lb_service_ip" {
#   value = var.lb_service_ip
# }

output "bastion_public_ip" {
  value = samsungcloudplatformv2_vpc_publicip.bastion.publicip.ip_address
}

output "bastion_private_ip" {
  value = var.bastion_fixed_ip
}

output "ske_cluster_id" {
  value = samsungcloudplatformv2_ske_cluster.this.id
}

output "postgresql_cluster_id" {
  value = samsungcloudplatformv2_postgresql_cluster.this.id
}

output "postgresql_endpoint" {
  value = "${var.postgresql_service_ip_address}:${var.database_port}"
}

output "postgresql_engine_version_id_used" {
  value = local.pg_engine_version_id
}

output "image_id_used" {
  value = local.image_id
}


output "keypair_name" {
  value = samsungcloudplatformv2_virtualserver_keypair.kp.name
}

output "keypair_private_key" {
  value     = samsungcloudplatformv2_virtualserver_keypair.kp.private_key
  sensitive = true
}
