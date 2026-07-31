variable "cluster_name" {
  description = "EKS cluster name, used to tag/name VPC resources"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the EKS VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones for the cluster's public/private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets, one per AZ in var.azs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets, one per AZ in var.azs"
  type        = list(string)
}
