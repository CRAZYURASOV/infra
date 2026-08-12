variable "name" {
  type = string
}

variable "network_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "folder_id" {
  type    = string
  default = null
}

variable "targets" {
  description = "Список бэкендов: {subnet_id, ip_address}"
  type = list(object({
    subnet_id  = string
    ip_address = string
  }))
}

variable "locations" {
  description = "Зоны и подсети, где будут ноды самого балансировщика"
  type = list(object({
    zone_id   = string
    subnet_id = string
  }))
}

variable "backend_port" {
  type    = number
  default = 80
}

resource "yandex_alb_target_group" "this" {
  name      = "${var.name}-tg"
  folder_id = var.folder_id

  dynamic "target" {
    for_each = var.targets
    content {
      subnet_id  = target.value.subnet_id
      ip_address = target.value.ip_address
    }
  }
}

resource "yandex_alb_backend_group" "this" {
  name      = "${var.name}-bg"
  folder_id = var.folder_id

  http_backend {
    name             = "${var.name}-backend"
    port             = var.backend_port
    weight           = 1
    target_group_ids = [yandex_alb_target_group.this.id]

    load_balancing_config {
      panic_threshold = 50
    }

    healthcheck {
      timeout             = "1s"
      interval            = "2s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      healthcheck_port    = var.backend_port

      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "this" {
  name      = "${var.name}-router"
  folder_id = var.folder_id
}

resource "yandex_alb_virtual_host" "this" {
  name           = "${var.name}-vhost"
  http_router_id = yandex_alb_http_router.this.id

  route {
    name = "${var.name}-default-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.this.id
        timeout          = "3s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "this" {
  name       = var.name
  network_id = var.network_id
  folder_id  = var.folder_id

  security_group_ids = var.security_group_ids

  allocation_policy {
    dynamic "location" {
      for_each = var.locations
      content {
        zone_id   = location.value.zone_id
        subnet_id = location.value.subnet_id
      }
    }
  }

  listener {
    name = "${var.name}-http-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.this.id
      }
    }
  }
}

output "id" {
  value = yandex_alb_load_balancer.this.id
}

output "public_ip" {
  description = "Внешний IP балансировщика — на него и ходим curl'ом"
  value       = yandex_alb_load_balancer.this.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
}
