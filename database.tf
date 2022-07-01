
resource "aws_db_instance" "visual_regression_rds_instance" {
  engine         = "mysql"
  engine_version = "8.0.23"
  instance_class = "db.t2.micro"
  // required unless a snapshot identifier is provided
  // if using a snapshot the database already has a master username
  # username                  = var.vrtesting_rds_username
  password = var.vrtesting_rds_password
  # snapshot_identifier = data.aws_db_snapshot.latest_snapshot.id
  snapshot_identifier       = var.vrtesting_rds_snapshot
  final_snapshot_identifier = "${var.vrtesting_environment}-web-db-snaphot-${replace(timestamp(), ":", "-")}"
  db_subnet_group_name      = aws_db_subnet_group.db_subnet.name
  publicly_accessible       = var.vrtesting_rds_publicly_accessible

  #  lifecycle {
  #    ignore_changes = [
  #      final_snapshot_identifier,
  #    ]
  #  }

  vpc_security_group_ids = [aws_security_group.db_security_group.id]

  lifecycle {
    ignore_changes = [snapshot_identifier]
  }
}

#data "aws_db_snapshot" "latest_prod_snapshot" {
#  db_instance_identifier = aws_db_instance.visual_regression_rds_instance.id
#  most_recent            = true
#}
#
#data "aws_db_snapshot" "prod" {
#  db_instance_identifier = aws_db_instance.visual_regression_rds_instance.id
#  db_snapshot_identifier = var.vrtesting_rds_snapshot
#}

# todo should RDS use or go off migration (not important for initial deployment test)
