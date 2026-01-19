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
}
