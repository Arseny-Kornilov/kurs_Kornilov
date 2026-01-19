resource "yandex_vpc_network" "main" {
  name = "main-network"
}

# Subnet A - Private

resource "yandex_vpc_subnet" "foo1" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

# Subnet B - Private (vm2,vm3)

resource "yandex_vpc_subnet" "foo2" {
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.5.1.0/24"]
}

# Subnet C - Public (Grafana,Kibana,application load balancer)

resource "yandex_vpc_subnet" "foo3" {
  name           = "public-subnet"
  zone           = "ru-central1-c"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}


# Security Group 1 - Web Servers

resource "yandex_vpc_security_group" "web_servers_sg" {
  name        = "web-servers-sg"
  description = "Security group for web servers (nginx)"
  network_id  = yandex_vpc_network.main.id

  ingress {
    description    = "Allow HTTP from anywhere"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    description    = "Allow HTTPS from anywhere"
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    description    = "Allow SSH from trusted IPs"
    protocol       = "TCP"
    v4_cidr_blocks = ["your.trusted.ip/32"]  # Только ваш IP!
    port           = 22
  }

  ingress {
    description    = "Allow Node Exporter from Prometheus"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.128.0.12/32"]  # Только Prometheus (vm3)
    port           = 9100
  }

  ingress {
    description    = "Allow Nginx Log Exporter from Prometheus"
    protocol       = "TCP"
    v4_cidr_blocks = ["10.128.0.12/32"]  # Только Prometheus (vm3)
    port           = 4040
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
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
      size     = 8
    }
  }

  resources {
    cores  = 2
    memory = 4
  }

  # Network interface
  network_interface {
    index              = 0
    subnet_id          = yandex_vpc_subnet.foo1.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.default.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml") # Используйте file() для чтения файла
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("~/.ssh/id_ed25519.pub")}"
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
      size     = 8
    }
  }

  resources {
    cores  = 2
    memory = 4
  }

  # Network interface
  network_interface {
    index              = 0
    subnet_id          = yandex_vpc_subnet.foo2.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.default.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml") # Используйте file() для чтения файла
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("~/.ssh/id_ed25519.pub")}"
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
      size     = 8
    }
  }

  resources {
    cores  = 2
    memory = 4
  }

  # Network interface
  network_interface {
    index              = 0
    subnet_id          = yandex_vpc_subnet.foo2.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.default.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml") # Используйте file() для чтения файла
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("~/.ssh/id_ed25519.pub")}"
  }
}

# VM 4 - Monitoring Grafana

resource "yandex_compute_instance" "vm4" {
  name        = "grafana"
  platform_id = "standard-v3"
  zone        = "ru-central1-c"

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
    security_group_ids = [yandex_vpc_security_group.default.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("~/.ssh/id_ed25519.pub")}"
  }
}

#VM 5 - Monitoring ElasticSearch

resource "yandex_compute_instance" "vm5" {
  name        = "elasticsearch"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

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
    subnet_id          = yandex_vpc_subnet.foo2.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.default.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("~/.ssh/id_ed25519.pub")}"
  }
}

#VM 6 - Monitoring Kibana

resource "yandex_compute_instance" "vm6" {
  name        = "kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-c"

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
    security_group_ids = [yandex_vpc_security_group.default.id]
  }
  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
    ssh-keys           = "vboxuser:${file("~/.ssh/id_ed25519.pub")}"
  }
}


# Target Group

resource "yandex_lb_target_group" "tg" {
  name = "target-group"

  dynamic "target" {
    for_each = [
      yandex_compute_instance.vm1,
      yandex_compute_instance.vm2
    ]

    content {
      subnet_id = target.value.network_interface[0].subnet_id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

# Backend Group

resource "yandex_alb_backend_group" "https_backend_group" {
  name = "https-backend-group"

  http_backend {
    name             = "https-backend"
    port             = 80
    target_group_ids = [yandex_lb_target_group.tg.id]

    healthcheck {
      timeout  = "1s"
      interval = "2s"


      http_healthcheck {
        path = "/"
      }
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
        backend_group_id = yandex_alb_backend_group.https_backend_group.id
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
      zone_id   = "ru-central1-c"
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
      auto_http_handler {
        http_router_id = yandex_alb_http_router.my_router.id
      }
    }
  }
}

# Backup

resource "yandex_compute_snapshot_schedule" "daily_backup" {
  name = "daily-vm-backups"
  description = "Daily automated snapshots with 1-week retention"

  # Расписание: каждый день в 01:00 ночи
  schedule_policy {
    expression = "0 1 * * *"  # cron формат
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
    yandex_compute_instance.vm3.boot_disk[0].disk_id,  # Prometheus
    yandex_compute_instance.vm4.boot_disk[0].disk_id,  # Grafana
    
    # ELK stack
    yandex_compute_instance.vm5.boot_disk[0].disk_id,  # Elasticsearch
    yandex_compute_instance.vm6.boot_disk[0].disk_id,  # Kibana
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