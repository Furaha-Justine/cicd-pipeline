[jenkins]
${jenkins_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[app_servers]
${app_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
