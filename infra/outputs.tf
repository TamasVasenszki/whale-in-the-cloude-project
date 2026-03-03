output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "server_az1_private_ip" {
  value = aws_instance.server_az1.private_ip
}

output "server_az2_private_ip" {
  value = aws_instance.server_az2.private_ip
}

output "app_image_uri" {
  value = local.app_image
}