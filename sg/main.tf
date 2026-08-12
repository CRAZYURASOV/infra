variable "name" {
  type = string
}

variable "network_id" {
  type = string
}

variable "folder_id" {
  type    = string
  default = null
}

variable "allow_http_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "allow_ssh_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "labels" {
  type    = map(string)
  default = {}
}

# Единая security group на весь стенд: висит и на ALB-нодах, и на инстансах.
# Для дев-окружения это осознанное упрощение — в проде разносят на sg-alb и sg-backend отдельно.
resource "yandex_vpc_security_group" "this" {
  name       = var.name
  network_id = var.network_id
  folder_id  = var.folder_id
  labels     = var.labels

  ingress {
    description    = "HTTP снаружи"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = var.allow_http_cidrs
  }

  ingress {
    description    = "SSH для администрирования"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = var.allow_ssh_cidrs
  }

  # Health-check трафик от ALB/NLB приходит именно с этих диапазонов.
  # Без этого правила таргеты никогда не станут HEALTHY.
  ingress {
    description       = "Health checks от ALB/NLB"
    protocol          = "TCP"
    port              = 30080
    predefined_target = "loadbalancer_healthchecks"
  }

  egress {
    description    = "Разрешить весь исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

output "id" {
  value = yandex_vpc_security_group.this.id
}
