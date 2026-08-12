variable "name" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "ssh_public_key" {
  type        = string
  description = "Публичный SSH-ключ, будет добавлен для пользователя ubuntu"
}

variable "folder_id" {
  type    = string
  default = null
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2
}

variable "disk_size_gb" {
  type    = number
  default = 20
}

variable "preemptible" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "this" {
  name        = var.name
  zone        = var.zone
  folder_id   = var.folder_id
  platform_id = "standard-v3"
  labels      = var.labels
  preemptible = var.preemptible

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.disk_size_gb
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = true
    security_group_ids = var.security_group_ids
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    user-data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      server_name = var.name
    })
  }

  # image_id меняется при выходе новых версий ubuntu-2204-lts —
  # не хотим пересоздавать инстанс на каждый terraform plan из-за этого.
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image_id]
  }
}

output "id" {
  value = yandex_compute_instance.this.id
}

output "internal_ip" {
  value = yandex_compute_instance.this.network_interface[0].ip_address
}

output "external_ip" {
  value = yandex_compute_instance.this.network_interface[0].nat_ip_address
}
