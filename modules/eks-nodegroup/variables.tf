variable "cluster_name" {
  description = "EKS cluster name the node group attaches to"
  type        = string
}

variable "nodegroup_name" {
  description = "Name of the EKS managed node group"
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for the node group"
  type        = string
}

variable "node_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
}

variable "node_volume_size" {
  description = "Root EBS volume size (GiB) for each node"
  type        = number
}

variable "ssh_public_key_name" {
  description = <<-EOT
    Name of an existing EC2 key pair to enable SSH access to nodes. Leave blank
    (the default) to skip SSH access entirely.
  EOT
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs where node group instances are launched"
  type        = list(string)
}
