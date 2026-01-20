terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.129.0"
    }
  }

  required_version = ">=1.8.4"
}

provider "yandex" {
  service_account_key_file = "/home/vboxuser/authorized_key.json"
  cloud_id                 = "b1gc4hg3apeuqktj3l58"
  folder_id                = "b1g95b3p66i5e05fo7pa"
  # Можете указать zone или нет
  zone                     = "ru-central1-a"
}

# Дополнительные провайдеры ДОЛЖНЫ иметь alias
provider "yandex" {
  alias                    = "zone_b"  # ← ОБЯЗАТЕЛЬНО!
  service_account_key_file = "/home/vboxuser/authorized_key.json"
  cloud_id                 = "b1gc4hg3apeuqktj3l58"
  folder_id                = "b1g95b3p66i5e05fo7pa"
  zone                     = "ru-central1-b"
}

provider "yandex" {
  alias                    = "zone_c"  # ← ОБЯЗАТЕЛЬНО!
  service_account_key_file = "/home/vboxuser/authorized_key.json"
  cloud_id                 = "b1gc4hg3apeuqktj3l58"
  folder_id                = "b1g95b3p66i5e05fo7pa"
  zone                     = "ru-central1-d"
}