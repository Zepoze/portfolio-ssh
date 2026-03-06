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
  environment = toset(["dev","staging","prod"])
}

resource "aws_iam_role" "ec2_role" {
  for_each = local.environment
  name = "tf-${var.app_name}-ec2-role-${each.key}"

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

resource "aws_iam_policy" "ecr_login" {
  name = "tf-${var.app_name}-ecr-login"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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

resource "aws_iam_role_policy_attachment" "ec2_role_ecr_login" {
  for_each = local.environment
  role       = aws_iam_role.ec2_role[each.key].name
  policy_arn = aws_iam_policy.ecr_login.arn
}

resource "aws_iam_policy" "ecr_read_only" {
  for_each = local.app_repos
  name        = "tf-${var.app_name}-${each.key}-ecr-read-only-policy"
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
      }
    ]
  })
}

locals {
  env_app_repos = {
    for env in local.environment :
    env => local.app_repos
  }
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy" {
  for_each = {
    for pair in flatten([
      for env, apps in local.env_app_repos : [
        for app in apps : {
          key   = "${env}-${app}"
          env = env
          app  = app
        }
      ]
    ]) : pair.key => pair
  }
  role       = aws_iam_role.ec2_role[each.value.env].name
  policy_arn = aws_iam_policy.ecr_read_only[each.value.app].arn
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy_ssm" {
  for_each = local.environment
  role       = aws_iam_role.ec2_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "secret_sshost" {
  for_each = local.environment
  name        = "tf-${var.app_name}-getsecret-sshhost-policy-${each.key}"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:eu-west-3:160927904376:secret:portfolio-ssh/${each.key}/ssh_hostkey*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_secret" {
  for_each = local.environment
  role       = aws_iam_role.ec2_role[each.key].name
  policy_arn = aws_iam_policy.secret_sshost[each.key].arn
}

resource "aws_iam_policy" "s3_artefect_ro" {
  for_each = local.environment
  name        = "tf-${var.app_name}-artefacts_ro-${each.key}"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::tfartefacts-zshowcase-eu-west-3/artefacts/portfolio-ssh/${each.key}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::tfartefacts-zshowcase-eu-west-3"
        Condition = {
          StringLike = {
            "s3:prefix" = ["arn:aws:s3:::tfartefacts-zshowcase-eu-west-3/artefacts/portfolio-ssh/${each.key}/*"]
          }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_artefacts_s3" {
  for_each = local.environment
  role       = aws_iam_role.ec2_role[each.key].name
  policy_arn = aws_iam_policy.s3_artefect_ro[each.key].arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  for_each = local.environment
  name = "tf-${var.app_name}-ec2-profile-${each.key}"
  role = aws_iam_role.ec2_role[each.key].name
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
  for_each = local.environment

  ami           = data.aws_ami.al2.id
  instance_type = "t3.micro"

  root_block_device {
    volume_size           = 25        # Go
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile[each.key].name

  user_data = templatefile("${path.module}/user_data.sh.tftpl",{
    region = var.region
    channel = each.key
    region = var.region
    ecr_url = local.ecr_url
    docker_compose = file("${path.module}/docker-compose.yml")
    deploy_script = file("${path.module}/deploy.sh")
    ssh_host_key_secret_id = aws_secretsmanager_secret.ssh_hostkey[each.key].arn
    update_proxy_host_key_script = file("${path.module}/update_ssh_hostkey.sh")
    artefact_bucket_folder = "tfartefacts-zshowcase-eu-west-3/artefacts/portfolio-ssh/${each.key}"
  })

  tags = {
    Name = "${var.app_name}-ec2-${each.key}"
    App = "${var.app_name}"
  }
}

resource "aws_secretsmanager_secret" "ssh_hostkey" {
  for_each = local.environment
  name        = "portfolio-ssh/${each.key}/ssh_hostkey"
  description = "SSH host key for myapp ${each.key} environment"

  tags = {
    App = "portfolio-ssh"
    Env = "${each.key}"
  }
}


