variable "cluster_id" {
  description = "e.g. microservice1-develop-gateway-cache"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_type" {
  description = "Cheapest node type for a demo"
  type        = string
  default     = "cache.t4g.micro"
}

variable "engine_version" {
  type    = string
  default = "7.1"
}

variable "port" {
  type    = number
  default = 6379
}
