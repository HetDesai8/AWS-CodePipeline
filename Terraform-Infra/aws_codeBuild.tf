module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "Het-codebuild-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false
  create_igw         = true

  tags = {
    Name = "Het"
  }
}

resource "aws_security_group" "aws-sg" {
  name        = "Het-codebuild-sg"
  description = "Allow all inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Het"
  }
}


resource "aws_s3_bucket" "s3-bucket" {
  bucket = "het-s3-bucket8"
  tags = {
    Name = "Het"
  }
}

# resource "aws_s3_bucket_acl" "s3-bucket-acl" {
#   bucket = aws_s3_bucket.s3-bucket.id
#   acl    = "private"
# }

# resource "aws_s3_bucket_policy" "s3-bucket-policy" {
#   bucket = aws_s3_bucket.s3-bucket.id

#   policy = <<POLICY
#   {
#     "Version": "2012-10-17",
#     "Statement": [
#       {
#         "Sid": "AllowGetObject",
#         "Effect": "Allow",
#         "Principal": "*",
#         "Action": "s3:GetObject",
#         "Resource": "arn:aws:s3:::het-s3-bucket8/*"
#       }
#     ]
#   }
#   POLICY
# }


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam-role" {
  name               = "Het-iam-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "iam-policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  # statement {
  #   effect = "Allow"

  #   actions = [
  #     "ecr:GetAuthorizationToken",
  #       "ecr:BatchCheckLayerAvailability",
  #       "ecr:GetDownloadUrlForLayer",
  #       "ecr:GetRepositoryPolicy",
  #       "ecr:DescribeRepositories",
  #       "ecr:ListImages",
  #       "ecr:DescribeImages",
  #       "ecr:BatchGetImage",
  #       "logs:CreateLogGroup",
  #       "logs:CreateLogStream",
  #       "logs:PutLogEvents"
  #   ]

  #   resources = ["*"]
  # }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateNetworkInterfacePermission"]
    resources = ["arn:aws:ec2:us-east-1:123456789012:network-interface/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"

      values = [
        module.vpc.public_subnet_arns[0],
        module.vpc.public_subnet_arns[1]

      ]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.s3-bucket.arn,
      "${aws_s3_bucket.s3-bucket.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "example" {
  role   = aws_iam_role.iam-role.name
  policy = data.aws_iam_policy_document.iam-policy.json
}


resource "aws_codebuild_project" "example_codebuild" {
  name          = "Het-codebuild-project"
  description   = "CodeBuild project"
  service_role  = aws_iam_role.iam-role.arn
  build_timeout = 60

  source {
    type            = "CODECOMMIT"
    location        = aws_codecommit_repository.codecommit.clone_url_http
    git_clone_depth = 1
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "ECR_REPO"
      value = aws_ecr_repository.my_ecr_repo.repository_url
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "log-group"
      stream_name = "log-stream"
    }
  }

}