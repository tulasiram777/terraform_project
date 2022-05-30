output "publicip_web1" {
  value = aws_instance.web1.public_ip
}

output "publicip_web2" {
  value = aws_instance.web2.public_ip
}

output "alb_dns" {
  value = aws_lb.custom_alb.dns_name
}