variable "name" {
  type        = string
  description = "Имя сети"
}

variable "cidr" {
  type        = string
  description = "Базовый CIDR сети, например 10.10.0.0/16"
}

variable "zones" {
  type        = list(string)
  description = "Список зон доступности, в каждой создаётся своя подсеть"
}

variable "folder_id" {
  type        = string
  default     = null
  description = "ID папки; если не задан — берётся из provider"
}

variable "labels" {
  type    = map(string)
  default = {}
}

# Делим базовый CIDR на подсети по числу зон.
# /16 -> берём /24 под каждую зону, этого с запасом хватит под dev-стенд.
locals {
  subnet_cidrs = {
    for idx, zone in var.zones :
    zone => cidrsubnet(var.cidr, 8, idx)
  }
}

resource "yandex_vpc_network" "this" {
  name      = var.name
  folder_id = var.folder_id
  labels    = var.labels
}

resource "yandex_vpc_subnet" "this" {
  for_each = local.subnet_cidrs

  name           = "${var.name}-${each.key}"
  zone           = each.key
  network_id     = yandex_vpc_network.this.id
  v4_cidr_blocks = [each.value]
  folder_id      = var.folder_id
  labels         = var.labels
}

output "network_id" {
  value = yandex_vpc_network.this.id
}

output "subnet_ids" {
  description = "Карта зона -> subnet_id"
  value       = { for z, s in yandex_vpc_subnet.this : z => s.id }
}

output "subnet_cidrs" {
  value = local.subnet_cidrs
}
