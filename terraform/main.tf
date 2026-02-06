provider "aws" {
  region = var.region
  /*assume_role {
    role_arn = "arn:aws:iam::160927904376:role/tf-role-zshowcase-portfolio-ssh"
  }
  */
}


data "aws_caller_identity" "current" {}

# --- 1) ECR repo ---
resource "aws_ecr_repository" "app" {
  name                 = "tf-${var.app_name}-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Auth ECR pour le provider Docker (pour push)
data "aws_ecr_authorization_token" "token" {}

# Exemple d'URL: https://1234567890.dkr.ecr.eu-west-3.amazonaws.com
locals {
  ecr_url     = aws_ecr_repository.app.repository_url
}

provider "docker" {
  registry_auth {
    address  = replace(data.aws_ecr_authorization_token.token.proxy_endpoint, "https://", "")
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

resource "docker_image" "slides" {
  name = "${local.ecr_url}:slides-${tofu.workspace}"

  build {
    context = "${path.module}/../slides"
  }
}

resource "docker_image" "proxy" {
  name = "${local.ecr_url}:proxy-${tofu.workspace}"

  build {
    context = "${path.module}/../proxy"
  }
}

resource "docker_registry_image" "slides" {
  name          = docker_image.slides.name
  keep_remotely = true
}

resource "docker_registry_image" "proxy" {
  name          = docker_image.proxy.name
  keep_remotely = true
}

data "aws_iam_instance_profile" "ec2_profile" {
  name = var.instance_profile_name
}

resource "aws_iam_role" "ec2_role" {

  name = "tf-${var.app_name}-ec2-role-${tofu.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ecr_read_only" {
  name        = "tf-${var.app_name}-ecr-read-only-policy-${tofu.workspace}"
  description = "Policy to allow read-only access to ECR for EC2 instances"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ecr_read_only.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "tf-${var.app_name}-ec2-profile-${tofu.workspace}"
  role = aws_iam_role.ec2_role.name
}

# AMI Amazon Linux 2
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2 Instance
resource "aws_instance" "app" {
  count = var.active && tofu.workspace == "dev" ? 1 : 0

  ami           = data.aws_ami.al2.id
  instance_type = "t3.micro"

  root_block_device {
    volume_size           = 25        # Go
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  #iam_instance_profile = data.aws_iam_instance_profile.ec2_profile.name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = templatefile("${path.module}/user_data.sh.tftpl",{
    region = var.region
    ecr_url = local.ecr_url
    docker_compose = templatefile("${path.module}/docker-compose.yml.tftpl",{
      slides_image = "${aws_ecr_repository.app.repository_url}:slides-${tofu.workspace}"
      proxy_image = "${aws_ecr_repository.app.repository_url}:proxy-${tofu.workspace}"
    })
  })

  depends_on = [docker_registry_image.proxy, docker_registry_image.slides]

  tags = {
    Name = "${var.app_name}-ec2"
  }
}
