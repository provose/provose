output "aws_volume_attachment" {
  value = {
    on_demand = aws_volume_attachment.main__ondemand
    spot      = aws_volume_attachment.main__spot
  }
}

output "aws_instance" {
  value = {
    on_demand = aws_instance.main
    spot      = aws_spot_instance_request.main
  }
}
