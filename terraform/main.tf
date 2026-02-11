provider "aws" {
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::160927904376:role/tf-role-zshowcase-portfolio-ssh"
  }
}


data "aws_caller_identity" "current" {}

locals {
  app_repos = toset(["slides","proxy"])
}

# --- 1) ECR repo ---
resource "aws_ecr_repository" "app" {
  for_each             =  local.app_repos
  name                 = "tf-${var.app_name}-${each.key}-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Auth ECR pour le provider Docker (pour push)
data "aws_ecr_authorization_token" "token" {}

# Exemple d'URL: https://1234567890.dkr.ecr.eu-west-3.amazonaws.com
locals {
  ecr_url = {
    for k,v in local.app_repos : k=> aws_ecr_repository.app[k].repository_url
  }
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
  for_each = local.app_repos
  name        = "tf-${var.app_name}-${each.key}-ecr-read-only-policy-${tofu.workspace}"
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
        Resource = aws_ecr_repository.app[each.key].arn
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
  for_each = local.app_repos
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ecr_read_only[each.key].arn
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
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

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = templatefile("${path.module}/user_data.sh.tftpl",{
    region = var.region
    ecr_url = local.ecr_url
    docker_compose = file("${path.module}/docker-compose.yml")
    deploy_script = templatefile("${path.module}/deploy.tftpl.sh",{
      channel = tofu.workspace
      ecr_url = local.ecr_url
    })
  })

  tags = {
    Name = "${var.app_name}-ec2"
    App = "${var.app_name}"
  }
}

output "ec_instance_id" {
  value = (var.active && tofu.workspace == "dev" || tofu.workspace != "dev") ? aws_instance.app[0].id : null
  description = "ID of the EC2 instance"
  
}