output "public_ip" {
  value = aws_instance.web.private_ip
}

output "public_dns" {
  value = aws_instance.web.private_dns
}