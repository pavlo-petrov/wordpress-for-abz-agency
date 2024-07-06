provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket         = "mybucketfortest-2024-07-04-test"
    key            = "wordpress/prod/terraform.tfstate"
    region         = "eu-west-1"
  #  dynamodb_table = "terraform-lock-table" #### іншим разом..... 
  }
}


resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public_subnet" {
  count      = length(var.public_subnet_cidrs)
  vpc_id     = aws_vpc.main.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

 tags = {
   Name = "Public work Subnet ${count.index + 1}"
 }
}

resource "aws_subnet" "admin_subnet" {
  count     = length(var.admin_subnet_cidrs) 
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.admin_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

tags = {
  Name = "Public admin Subnet ${count.index + 1}"
 }
}

resource "aws_subnet" "database_subnet" {
  count = length(var.databases_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.databases_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

tags = {
  Name = "private database Subnet ${count.index + 1}"
 }
}  

resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.main.id

 tags = {
   Name = "VPC Internet Gateway"
 }
}

resource "aws_route_table" "route_table_default" {
 vpc_id = aws_vpc.main.id

 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id

 }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.route_table_default.id
}

resource "aws_route_table_association" "admin_subnet_association" {
  count          = length(aws_subnet.admin_subnet)
  subnet_id      = aws_subnet.admin_subnet[count.index].id
  route_table_id = aws_route_table.route_table_default.id
}


############## MySQL #################

# DB Subnet Group
resource "aws_db_subnet_group" "default" {
  name       = "my-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.database_subnet[*] : subnet.id]

  tags = {
    Name = "My DB subnet group"
  }
}


resource "aws_security_group" "db" {
  name        = var.db_security_group_name
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id # замініть на ваш VPC ID

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_db_instance" "default" {
  identifier              = var.db_instance_identifier
  engine                  = "mysql"
  engine_version          = "8.0.35"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  max_allocated_storage   = 30  # autoscailing до 30 Гб
  storage_type            = "gp2"
  username                = var.db_username
  password                = jsondecode(data.aws_secretsmanager_secret_version.example.secret_string)["password_for_mysql"] 
  db_subnet_group_name    = aws_db_subnet_group.default.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  availability_zone       = var.db_rds_avail_zone[0]
  port                    = 3306
  multi_az                = false
  auto_minor_version_upgrade = true
  backup_retention_period = 0  # Вимкнути backup
  skip_final_snapshot     = true  # Вимкнути snapshot при видаленні
  deletion_protection     = false  # Вимкнути захист від видалення
  publicly_accessible     = false
  storage_encrypted       = true  # Увімкнути шифрування

  iam_database_authentication_enabled = true  # IAM database authentication

  monitoring_interval     = 0  # Вимкнути Enhanced Monitoring

  depends_on = [
    aws_subnet.database_subnet
  ]

  tags = {
    Name = "MySQL-Database"
  }
}


data "aws_secretsmanager_secret" "example" {
  name = "test_mysql_pass"
}

data "aws_secretsmanager_secret_version" "example" {
  secret_id = data.aws_secretsmanager_secret.example.id
}

##################### Redis ################

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = [for subnet in aws_subnet.database_subnet[*] : subnet.id]
}


resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "my-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.db.id]
}

######################## ELB ##############

# resource "aws_elb" "example_elb" {
#   name               = "example-elb"
#   availability_zones = var.azs
#   listener {
#     lb_port           = 80
#     lb_protocol       = "http"
#     instance_port     = 80
#     instance_protocol = "http"
#   }
#  subnets              = ["subnet-0c3d66cdcc7b8b9db", "subnet-0f2a42aba3e897ff7", "subnet-0cce7261a1367067b"]
# }