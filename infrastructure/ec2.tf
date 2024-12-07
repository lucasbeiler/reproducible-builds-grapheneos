resource "aws_instance" "machine" {
  ami           = data.aws_ami.debian.image_id
  instance_type = local.instance_type
  key_name      = local.key_name
  user_data     = local.user_data

  iam_instance_profile = aws_iam_instance_profile.instance_profile.id

  ebs_block_device {
    device_name = data.aws_ami.debian.root_device_name
    volume_size = local.volume_size_gb
  }

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_dns
  }

  provisioner "file" {
    source      = "../scripts"
    destination = "scripts/"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p scripts/",
    ]
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = local.spot_price
    }
  }
}

resource "aws_key_pair" "generated_key" {
  key_name   = local.key_name
  public_key = tls_private_key.private_key.public_key_openssh
}


resource "tls_private_key" "private_key" {
  algorithm = "ED25519"
}
