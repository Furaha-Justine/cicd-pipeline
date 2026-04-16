variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "cicd-demo"
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins (needs at least 2GB RAM)"
  type        = string
  default     = "t3.medium"
}

variable "app_instance_type" {
  description = "EC2 instance type for the app server"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port the app container listens on"
  type        = number
  default     = 3000
}
