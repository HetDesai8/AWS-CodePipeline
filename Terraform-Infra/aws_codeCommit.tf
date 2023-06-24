resource "aws_codecommit_repository" "codecommit" {
  repository_name = "Het-codecommit-repo"
  description     = "CodeCommit Repository"
}