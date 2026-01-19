output "vm1_internal_ip" {
  value = yandex_compute_instance.vm1.network_interface[0].ip_address
}

output "vm2_internal_ip" {
  value = yandex_compute_instance.vm2.network_interface[0].ip_address
}

output "vm3_internal_ip" {
  value = yandex_compute_instance.vm3.network_interface[0].ip_address
}

output "vm4_internal_ip" {
  value = yandex_compute_instance.vm4.network_interface[0].ip_address
}

output "vm5_internal_ip" {
  value = yandex_compute_instance.vm5.network_interface[0].ip_address
}
output "vm6_internal_ip" {
  value = yandex_compute_instance.vm6.network_interface[0].ip_address
}