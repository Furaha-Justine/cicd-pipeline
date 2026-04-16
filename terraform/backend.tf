
terraform {
  backend "s3" {
    bucket         = "cicd-demo-tfstate-furaha"      
    key            = "cicd-demo/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
