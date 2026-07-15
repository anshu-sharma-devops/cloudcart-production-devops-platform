output "instance_id" {
  description = "ID of the CloudCart lab EC2 instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the CloudCart lab EC2 instance"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the CloudCart lab EC2 instance"
  value       = aws_instance.this.private_ip
}

output "ami_id" {
  description = "Ubuntu AMI used by the EC2 instance"
  value       = aws_instance.this.ami
}

output "security_group_id" {
  description = "ID of the CloudCart application security group"
  value       = aws_security_group.this.id
}

output "iam_role_name" {
  description = "Name of the EC2 IAM role"
  value       = aws_iam_role.this.name
}