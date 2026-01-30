# outputs.tf
output "vm1_internal_ip" {
  description = "Internal IP address of Web Server 1"
  value       = yandex_compute_instance.vm1.network_interface[0].ip_address
}

output "vm2_internal_ip" {
  description = "Internal IP address of Web Server 2"
  value       = yandex_compute_instance.vm2.network_interface[0].ip_address
}

output "vm3_internal_ip" {
  description = "Internal IP address of Prometheus server"
  value       = yandex_compute_instance.vm3.network_interface[0].ip_address
}

output "vm4_internal_ip" {
  description = "Internal IP address of Grafana server"
  value       = yandex_compute_instance.vm4.network_interface[0].ip_address
}

output "vm5_internal_ip" {
  description = "Internal IP address of Elasticsearch server"
  value       = yandex_compute_instance.vm5.network_interface[0].ip_address
}

output "vm6_internal_ip" {
  description = "Internal IP address of Kibana server"
  value       = yandex_compute_instance.vm6.network_interface[0].ip_address
}

output "bastion_external_ip" {
  description = "External IP address of Bastion host"
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}