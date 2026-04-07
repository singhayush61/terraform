output "hello-world" {
  description = "Print a Hello World text output"
  value       = "Hello World"
}

output "vpc_id" {
  description = "Output the ID for the primary VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_information" {
  description = "VPC Information"
  value       = "Your ${aws_vpc.vpc.tags.Name} VPC has an ID of ${aws_vpc.vpc.id}"
} # <--- This MUST be on its own line