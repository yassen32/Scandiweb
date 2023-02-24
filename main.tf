module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"
  name = "my-vpc"
  cidr = var.vpcCidrBlock

  azs             = var.azs
  private_subnets = var.private_subnet
  public_subnets  = var.public_subnet

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}
#BastionSecuritygroup
resource "aws_security_group" "bastion-sg" {
name = "allow-ssh"
vpc_id = module.vpc.vpc_id
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}
resource "aws_instance" "Bastion_Host" {
  ami             = var.ami
  key_name        = var.key_pair_name
  instance_type   = var.instance_type
  subnet_id       = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion-sg.id]
  tags = {
    Name = "Public Host"
  }
  user_data = <<-EOF
  #cloud-config
  ssh_authorized_keys:
    - ${var.public_key}
  EOF

}






resource "aws_security_group" "varnish-sg" {
vpc_id = module.vpc.vpc_id
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
security_groups = [aws_security_group.lb_sg.id]
}
ingress {
from_port = 443
to_port = 443
protocol = "tcp"
security_groups = [aws_security_group.lb_sg.id]
}

ingress {
from_port = 6081
to_port = 6081
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_instance" "varnish_server" {
ami = var.ami  # Ubuntu 18.04 LTS
instance_type = var.instance_type
key_name = var.key_pair_name
vpc_security_group_ids = [aws_security_group.varnish-sg.id]
subnet_id = module.vpc.private_subnets[0]
tags = {
Name = "Varnish_server"
}

user_data = <<-EOF
#!/bin/bash
sudo apt update
sudo apt install varnish -y
sudo apt install nginx -y
sudo service varnish enable
sudo tee /etc/varnish/default.vcl <<VCL
vcl 4.0;

backend magento {
    .host = "localhost";
    .port = "80";
}


}
VCL
sudo service varnish restart
sudo service nginx enable
sudo service nginx start

sudo tee /var/www/html/index.* <<HTML
<html>
<head>
  <title>Varnish is running</title>
</head>
<body>
  <h1>Varnish is running</h1>
</body>
</html>
HTML
EOF

}

resource "aws_security_group" "magento-sg" {
vpc_id = module.vpc.vpc_id
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
security_groups = [aws_security_group.lb_sg.id]
}

ingress {
from_port = 443
to_port = 443
protocol = "tcp"
security_groups = [aws_security_group.lb_sg.id]
}
ingress {
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}



egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_instance" "magento_server" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.magento-sg.id]
  subnet_id     = module.vpc.private_subnets[1]

  tags = {
    Name = "Magento_server"
  }


user_data = <<-EOF
#!/bin/bash
curl localhost

# Update and install required packages
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install -y --quiet php7.4 php7.4-mysql php7.4-curl php7.4-gd php7.4-intl php7.4-json php7.4-mbstring php7.4-xml php7.4-zip mysql-server nginx

## Download and extract Magento
sudo wget -q https://github.com/magento/magento2/archive/refs/tags/2.4.2.tar.gz
wait
sudo tar -xvf 2.4.2.tar.gz -C /var/www/html/ 
wait
# Set correct permissions
sudo chown -R www-data:www-data /var/www/html/magento2-2.4.2/
sudo chmod -R 755 /var/www/html/magento2-2.4.2/

#Authorize root user
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${var.db_password}'"
# Create MySQL database and user
sudo mysql -u root -p${var.db_password} -e "CREATE DATABASE magento"
sudo mysql -u root -p${var.db_password} -e "GRANT ALL PRIVILEGES ON magento.* TO 'magento'@'localhost' IDENTIFIED BY '${var.db_password}'"

# Install Composer
sudo curl -sS https://getcomposer.org/installer -o composer-setup.php
sudo HASH=`curl -sS https://composer.github.io/installer.sig`
sudo php -r "if (hash_file('SHA384', 'composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
sudo rm composer-setup.php

# Install Magento
cd /var/www/html/magento2-2.4.2/
sudo -u www-data composer install
sudo php bin/magento setup:install --base-url=http://localhost/ --db-host=localhost --db-name=magento --db-user=magento --db-password=${var.db_password} --admin-firstname=Admin --admin-lastname=User --admin-email=admin@example.com --admin-user=admin --admin-password=admin123 --language=en_US --currency=USD --timezone=America/Chicago --use-rewrites=1

# Create Magento systemd service
sudo tee /etc/systemd/system/magento.service > /dev/null <<EOF2
[Unit]
Description=Magento web application

[Service]
ExecStart=/usr/bin/php /var/www/html/magento2-2.4.2/bin/magento setup:cron:run
WorkingDirectory=/var/www/html/magento2-2.4.2
User=www-data
Restart=always

[Install]
WantedBy=multi-user.target
EOF2

# Enable and start the service
sudo systemctl enable magento
sudo systemctl start magento

# Configure Nginx
sudo tee /etc/nginx/sites-available/magento > /dev/null <<EOF3
server {
    listen 80;
    server_name localhost;
    root /var/www/html/magento2-2.4.2/pub;

    index index.php;
    location / {
        try_files \$uri \$uri/ /index.php\$is_args\$args;
    }
EOF3
# Enable and start the service
sudo systemctl enable nginx
sudo systemctl start nginx

# Restart Nginx to apply configuration changes
sudo systemctl restart nginx
EOF

  }


 



#Upload certificate to ACME
resource "aws_acm_certificate" "example" {
  private_key  = file("${path.module}/key.pem")
  certificate_body = file("${path.module}/cert.pem")
  tags = {
    Name = "ALB-cert"
  }
}




#ALB 
resource "aws_lb" "ALB" {
  name               = "example"
  load_balancer_type = "application"
  subnets = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]
  security_groups = [aws_security_group.lb_sg.id]
}
# Create the listener for HTTPS traffic
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ALB.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.example.arn
    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.varnish.arn
  }

}



# Create a rule that routes all requests to Varnish
resource "aws_lb_listener_rule" "varnish" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.varnish.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
# Create a rule that routes /media/* and /static/* requests directly to Magento
resource "aws_lb_listener_rule" "magento" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.magento.arn
  }

  condition {
    path_pattern {
      values = ["/media/*", "/static/*"]
    }


  }
}


#ALB Securitygroup
resource "aws_security_group" "lb_sg" {
name = "lb-sg"
vpc_id      = module.vpc.vpc_id
description = "Allow HTTP/HTTPS traffic"

ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
  ingress {
    from_port   = aws_lb_target_group.varnish.port
    to_port     = aws_lb_target_group.varnish.port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = aws_lb_target_group.magento.port
    to_port     = aws_lb_target_group.magento.port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
from_port = 443
to_port = 443
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
ingress {
from_port = 6081
to_port = 6081
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
}

# Target group
resource "aws_lb_target_group" "varnish" {
  name             = "varnish-tg"
  port             = 6081
  protocol         = "HTTP"
  target_type      = "instance"
  vpc_id           = module.vpc.vpc_id

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 3
    timeout             = 5
  }
}


resource "aws_lb_target_group" "magento" {
  name     = "magento-tg"
  port    = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  target_type      = "instance"

  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200-299"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }
}

resource "aws_lb_target_group_attachment" "varnish-attachment" {
  target_group_arn = aws_lb_target_group.varnish.arn
  target_id        = aws_instance.varnish_server.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "magento-attachment" {
  target_group_arn = aws_lb_target_group.magento.arn
  target_id        = aws_instance.magento_server.id
  port             = 80
}