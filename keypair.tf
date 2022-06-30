resource "aws_key_pair" "deployer" {
  key_name   = "${var.tag}-deploy-key"
  public_key = var.keypair
}
