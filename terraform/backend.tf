terraform {
  backend "s3" {
    bucket = "tfstate-zshowcase-eu-west-3"
    key    = "terraform.tfstate"
    region = "eu-west-3"
    dynamodb_table = "tf-locks-zshowcase"
    encrypt = true
    workspace_key_prefix = "states/portfolio-ssh"
  }
}
