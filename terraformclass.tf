terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# -------- Variables --------
variable "db_name" {
  type        = string
  default     = "appdb"
  description = "Initial database name"
}

variable "db_username" {
  type        = string
  default     = "admin"
  description = "Master username for the DB"
}

variable "allowed_cidr" {
  type        = string
  description = "CIDR allowed to reach MySQL (3306). Example: your public IP /32"
  # IMPORTANT: change this to your IP, e.g. "203.0.113.10/32"
  default     = "0.0.0.0/0"
}

# -------- Networking (default VPC + subnets) --------
data "aws_default_vpc" "default" {}

data "aws_default_subnet_ids" "default" {
  vpc_id = data.aws_default_vpc.default.id
}

resource "aws_db_subnet_group" "this" {
  name       = "mysql-subnet-group"
  subnet_ids = data.aws_default_subnet_ids.default.ids

  tags = {
    Name = "mysql-subnet-group"
  }
}

# -------- Security Group --------
resource "aws_security_group" "mysql" {
  name        = "mysql-rds-sg"
  description = "Allow MySQL access to RDS"
  vpc_id      = data.aws_default_vpc.default.id

  ingress {
    description = "MySQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql-rds-sg"
  }
}

# -------- Password --------
resource "random_password" "db" {
  length  = 20
  special = true
}

# -------- RDS MySQL --------
resource "aws_db_instance" "mysql" {
  identifier = "mysql-db-${replace(var.db_name, "_", "-")}"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.mysql.id]

  publicly_accessible = true

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "mysql-${var.db_name}"
  }
}

# -------- Outputs --------
output "mysql_endpoint" {
  value = aws_db_instance.mysql.address
}

output "mysql_port" {
  value = aws_db_instance.mysql.port
}

output "mysql_username" {
  value = var.db_username
}

output "mysql_password" {
  value     = random_password.db.result
  sensitive = true
}
