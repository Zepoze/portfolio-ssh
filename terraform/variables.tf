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

# Optionnel: si tu veux SSH, ajoute une key pair existante et décommente dans main.tf
variable "key_name" {
  type    = string
  default = null
}

variable "active" {
  type = bool
  default = true  
}

variable "domaine_name" {
  type = string
  default = "zepoze.fr"
}

variable "deactivate_dev" {
  type = bool
  default = false
}

variable "deactivate_staging" {
  type = bool
  default = false
}