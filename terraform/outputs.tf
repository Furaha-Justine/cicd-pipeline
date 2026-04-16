output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "app_public_ip" {
  value = aws_instance.app.public_ip
}

output "app_url" {
  value = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

output "ssh_jenkins" {
  value = "ssh -i terraform/ec2_key.pem ec2-user@${aws_instance.jenkins.public_ip}"
}

output "ssh_app" {
  value = "ssh -i terraform/ec2_key.pem ec2-user@${aws_instance.app.public_ip}"
}
