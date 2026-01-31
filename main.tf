resource "yandex_vpc_network" "main" {
  name = "main-network"
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "main_rt" {
  name       = "main-route-table"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id        = yandex_vpc_gateway.nat_gateway.id
  }
}


# Subnet A - Private

resource "yandex_vpc_subnet" "foo1" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.6.0.0/24"]
  route_table_id = yandex_vpc_route_table.main_rt.id
}

# Subnet B - Private (vm2,vm3)

resource "yandex_vpc_subnet" "foo2_new" {
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.7.0.0/24"]
  route_table_id = yandex_vpc_route_table.main_rt.id
}

# Subnet C - Public (Grafana,Kibana,application load balancer)

resource "yandex_vpc_subnet" "foo3" {
  name           = "public-subnet"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.10.0.0/24"]  
  route_table_id = yandex_vpc_route_table.main_rt.id
}

# Security Group для внутренней сети
resource "yandex_vpc_security_group" "private_network_sg" {
  name        = "private-network-sg"
  description = "Allow all traffic within private subnet"
  network_id  = yandex_vpc_network.main.id


  ingress {
    description    = "Allow all inside private subnet"
    protocol       = "ANY"
    v4_cidr_blocks = [
      yandex_vpc_subnet.foo1.v4_cidr_blocks[0],
      yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0],
    ]
  }

  ingress {
    description       = "Allow SSH only from Bastion host"
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.bastion_sg.id # ← Ключевое!
    port              = 22
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security group for Bastion host - SSH only"
  network_id  = yandex_vpc_network.main.id

  # ТОЛЬКО SSH из интернета
  ingress {
    description    = "Allow SSH from anywhere (или ограничьте свой IP)"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  # Разрешить SSH к приватным хостам
  egress {
    description    = "Allow SSH to private subnet"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 22
  }

  # Для обновлений пакетов
  egress {
    description    = "Allow HTTPS for updates"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
}

#Security Web Servers
resource "yandex_vpc_security_group" "web_servers_sg" {
  name        = "web-servers-sg"
  description = "Security group for web servers in private subnet"
  network_id  = yandex_vpc_network.main.id

  ingress {
    description       = "Allow SSH from Bastion"
    protocol          = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo3.v4_cidr_blocks[0]]
    port              = 22
  }
  # HTTP/HTTPS от ALB (публичная подсеть)
  ingress {
    description       = "Allow HTTP from ALB SG"
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.alb_sg.id
    port              = 80
  }

  # Метрики для Prometheus (из приватной подсети)
  ingress {
    description    = "Allow Node Exporter from monitoring subnet"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]] # Prometheus тоже в приватной
    port           = 9100
  }

  ingress {
    description    = "Allow Nginx Log Exporter from monitoring subnet"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 4040
  }

  # Отправка логов в Elasticsearch (приватная подсеть)
  egress {
    description    = "Allow sending logs to Elasticsearch"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]] # Elasticsearch в приватной
    port           = 9200
  }
}

#Security Group Prometheus
resource "yandex_vpc_security_group" "prometheus_sg" {
  name        = "prometheus-sg"
  description = "Security group for Prometheus in private subnet"
  network_id  = yandex_vpc_network.main.id

  ingress {
    description       = "Allow SSH from Bastion"
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  # Веб-интерфейс Prometheus - доступ из приватной подсети
  ingress {
    description    = "Allow Prometheus UI from private subnet"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 9090
  }

  # Сбор метрик с веб-серверов (приватная подсеть)
  egress {
    description    = "Allow to scrape web servers"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 9100
  }

  egress {
    description    = "Allow to scrape nginx logs"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 4040
  }
}

# Security group Elasticsearch
resource "yandex_vpc_security_group" "elasticsearch_sg" {
  name        = "elasticsearch-sg"
  description = "Security group for Elasticsearch in private subnet"
  network_id  = yandex_vpc_network.main.id

  ingress {
    description       = "Allow SSH from Bastion"
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }
  # API для Filebeat (из приватной подсети)
  ingress {
    description    = "Allow Elasticsearch API from private subnet"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]] # Веб-серверы в приватной
    port           = 9200
  }

  # Для Kibana (публичная подсеть)
  ingress {
    description    = "Allow Kibana access"
    protocol       = "TCP"
    security_group_id = yandex_vpc_security_group.kibana_sg.id
    port           = 9200
  }

}

#Security group Grafana
resource "yandex_vpc_security_group" "grafana_sg" {
  name        = "grafana-sg"
  description = "Security group for Grafana in public subnet"
  network_id  = yandex_vpc_network.main.id

  # Веб-интерфейс Grafana для всех
  ingress {
    description    = "Allow Grafana UI from anywhere"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }

  # SSH только из приватной подсети (или ваш IP)
  ingress {
    description       = "Allow SSH from Bastion"
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  # Доступ к Prometheus (приватная подсеть)
  egress {
    description    = "Allow connection to Prometheus"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 9090
  }
}

#Security Group Kibana
resource "yandex_vpc_security_group" "kibana_sg" {
  name        = "kibana-sg"
  description = "Security group for Kibana in public subnet"
  network_id  = yandex_vpc_network.main.id

  # Веб-интерфейс Kibana для всех
  ingress {
    description    = "Allow Kibana UI from anywhere"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  # SSH только из приватной подсети
  ingress {
    description       = "Allow SSH from Bastion"
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.bastion_sg.id
    port              = 22
  }

  # Доступ к Elasticsearch (приватная подсеть)
  egress {
    description    = "Allow connection to Elasticsearch"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 9200
  }
}

# Security group Application Load Balancer
resource "yandex_vpc_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for Application Load Balancer"
  network_id  = yandex_vpc_network.main.id

  # HTTP для всех
  ingress {
    description    = "Allow HTTP from anywhere"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  # HTTPS для всех (опционально)
  ingress {
    description    = "Allow HTTPS from anywhere"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  # Доступ к веб-серверам (приватная подсеть)
  egress {
    description    = "Allow to web servers"
    protocol       = "TCP"
    v4_cidr_blocks = [yandex_vpc_subnet.foo2_new.v4_cidr_blocks[0]]
    port           = 80
  }
}

# VM 1 - Web Server

resource "yandex_compute_instance" "vm1" {
  name        = "server1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  boot_disk {
    initialize_params {
      image_id = "fd8lcd9f54ldmonh1d72"
      size     = 10
    }
  }

  resources {
    cores  = 2
    memory = 4
  }

  # Network interface
  network_interface {
    index     = 0
    subnet_id = yandex_vpc_subnet.foo1.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.private_network_sg.id,
      yandex_vpc_security_group.web_servers_sg.id
    ]
  }
  metadata = {
    user-data          = file("./cloud-init.yml") # Используйте file() для чтения файла
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("/home/vboxuser/.ssh/id_ed25519.pub")}"
  }
}

# VM 2 -  Web Server

resource "yandex_compute_instance" "vm2" {
  name        = "server2"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  boot_disk {
    initialize_params {
      image_id = "fd8lcd9f54ldmonh1d72"
      size     = 10
    }
  }

  resources {
    cores  = 2
    memory = 4
  }

  # Network interface
  network_interface {
    index     = 0
    subnet_id = yandex_vpc_subnet.foo2_new.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.private_network_sg.id,
      yandex_vpc_security_group.web_servers_sg.id
    ]
  }
  metadata = {
    user-data          = file("./cloud-init.yml") # Используйте file() для чтения файла
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("/home/vboxuser/.ssh/id_ed25519.pub")}"
  }
}

#VM 3 - Monitoring Prometheus

resource "yandex_compute_instance" "vm3" {
  name        = "prometheus"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  boot_disk {
    initialize_params {
      image_id = "fd8lcd9f54ldmonh1d72"
      size     = 12
    }
  }

  resources {
    cores  = 2
    memory = 4
  }

  # Network interface
  network_interface {
    index     = 0
    subnet_id = yandex_vpc_subnet.foo2_new.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.private_network_sg.id,
      yandex_vpc_security_group.prometheus_sg.id
    ]
  }
  metadata = {
    user-data          = file("./cloud-init.yml") # Используйте file() для чтения файла
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("/home/vboxuser/.ssh/id_ed25519.pub")}"
  }
}

# VM 4 - Monitoring Grafana

resource "yandex_compute_instance" "vm4" {
  name        = "grafana"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  boot_disk {
    initialize_params {
      image_id = "fd8lcd9f54ldmonh1d72"
      size     = 12
    }
  }

  resources {
    cores  = 2
    memory = 4
  }

  # Network interface
  network_interface {
    index              = 0
    subnet_id          = yandex_vpc_subnet.foo3.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.grafana_sg.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("/home/vboxuser/.ssh/id_ed25519.pub")}"
  }
}

#VM 5 - Monitoring ElasticSearch

resource "yandex_compute_instance" "vm5" {
  name        = "elasticsearch"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  boot_disk {
    initialize_params {
      image_id = "fd8lcd9f54ldmonh1d72"
      size     = 12
    }
  }

  resources {
    cores  = 4
    memory = 8
  }

  # Network interface
  network_interface {
    index     = 0
    subnet_id = yandex_vpc_subnet.foo2_new.id
    nat       = false
    security_group_ids = [
      yandex_vpc_security_group.private_network_sg.id,
      yandex_vpc_security_group.elasticsearch_sg.id
    ]
  }
  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("/home/vboxuser/.ssh/id_ed25519.pub")}"
  }
}

#VM 6 - Monitoring Kibana

resource "yandex_compute_instance" "vm6" {
  name        = "kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  boot_disk {
    initialize_params {
      image_id = "fd8lcd9f54ldmonh1d72"
      size     = 12
    }
  }

  resources {
    cores  = 4
    memory = 8
  }

  # Network interface
  network_interface {
    index              = 0
    subnet_id          = yandex_vpc_subnet.foo3.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana_sg.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("/home/vboxuser/.ssh/id_ed25519.pub")}"
  }
}

#VM7 - Bastion

resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8lcd9f54ldmonh1d72"
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.foo3.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  metadata = {
    ssh-keys = "vboxuser:${file("/home/vboxuser/.ssh/id_ed25519.pub")}"
  }
}

# Target Group

resource "yandex_alb_target_group" "tg" {
  name = "target-group"

  target {
    subnet_id  = yandex_vpc_subnet.foo1.id
    ip_address = yandex_compute_instance.vm1.network_interface[0].ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.foo2_new.id
    ip_address = yandex_compute_instance.vm2.network_interface[0].ip_address
  }
}
# Backend Group

resource "yandex_alb_backend_group" "web_backend" {
  name = "web-backend-group"

  http_backend {
    name             = "web-backend"
    port             = 80
    target_group_ids = [yandex_alb_target_group.tg.id]

    healthcheck {
      timeout  = "1s"
      interval = "2s"
      http_healthcheck { path = "/" }
    }
  }
}

#HTTP Router

resource "yandex_alb_http_router" "my_router" {
  name = "my-http-router"
}

resource "yandex_alb_virtual_host" "my_virtual_host" {
  name           = "my-virtual-host"
  http_router_id = yandex_alb_http_router.my_router.id

  authority = ["*"]

  route {
    name = "root-route"

    http_route {
      http_match {
        path {
          exact = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_backend.id
      }
    }
  }
}

# Application Load Balancer
resource "yandex_alb_load_balancer" "web_alb" {
  name = "web-alb"

  network_id = yandex_vpc_network.main.id

  allocation_policy {
    location {
      zone_id   = "ru-central1-d"
      subnet_id = yandex_vpc_subnet.foo3.id
    }
  }

  listener {
    name = "auto-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }

    http {
      handler {
        http_router_id = yandex_alb_http_router.my_router.id
      }
    }
  }
}

# Backup

resource "yandex_compute_snapshot_schedule" "daily_backup" {
  name        = "daily-vm-backups"
  description = "Daily automated snapshots with 1-week retention"

  # Расписание: каждый день в 01:00 ночи
  schedule_policy {
    expression = "0 1 * * *" # cron формат
  }


  retention_period = "168h"



  snapshot_spec {
    description = "Automatic daily backup of VM disks"
  }

  disk_ids = [
    # Web servers
    yandex_compute_instance.vm1.boot_disk[0].disk_id,
    yandex_compute_instance.vm2.boot_disk[0].disk_id,

    # Monitoring stack
    yandex_compute_instance.vm3.boot_disk[0].disk_id, # Prometheus
    yandex_compute_instance.vm4.boot_disk[0].disk_id, # Grafana

    # ELK stack
    yandex_compute_instance.vm5.boot_disk[0].disk_id, # Elasticsearch
    yandex_compute_instance.vm6.boot_disk[0].disk_id, # Kibana
  ]

  # Зависимости - сначала должны быть созданы все VM
  depends_on = [
    yandex_compute_instance.vm1,
    yandex_compute_instance.vm2,
    yandex_compute_instance.vm3,
    yandex_compute_instance.vm4,
    yandex_compute_instance.vm5,
    yandex_compute_instance.vm6,
  ]
}
