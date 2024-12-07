locals {
  user_data            = base64encode(file("startup_script.sh"))
  spot_price           = "0.76"
  instance_type        = "c3.8xlarge"
  # instance_type        = "r4.2xlarge"
  volume_size_gb       = 384
  key_name             = "ec2_ssh_key"
}
