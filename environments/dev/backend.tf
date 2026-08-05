terraform {

  backend "s3" {

    bucket         = "ahmedyasser02-terraform-state"

    key            = "dev/terraform.tfstate"

    region         = "us-east-1"

    profile        = "dev"

    dynamodb_table = "terraform-locks"

    encrypt        = true

  }

}