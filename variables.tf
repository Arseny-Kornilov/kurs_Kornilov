variable "flow" {
  type    = string
  default = "24-01"
}

variable "test" {
  type = map(number)
  default = {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }
}

variable "cloud_id" {
  type    = string
  default = "b1gc4hg3apeuqktj3l58"
}

variable "folder_id" {
  type    = string
  default = "b1g95b3p66i5e05fo7pa"
}
