variable "region" {
  type    = string
  default = "eu-west-3"
}

variable "app_name" {
  type    = string
  default = "portfolio-ssh"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_profile_name" {
  type = string
  default = "ssh-portfolio-ecs-ec2-role"
}

# Optionnel: si tu veux SSH, ajoute une key pair existante et décommente dans main.tf
variable "key_name" {
  type    = string
  default = null
}

variable "active" {
  type = bool
  default = true  
}