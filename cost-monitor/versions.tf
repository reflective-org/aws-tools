terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 6.0 is the true floor: the per-resource `region` override used by
      # the chatbot channel configuration landed in provider v6.0 (the
      # aws_chatbot_* resources themselves only need >= 5.61).
      version = "~> 6.0"
    }
  }
}
