AWS VPC Infrastructure with ALB, ASG, NAT Gateways, and Jump Server

This Terraform configuration provisions a complete production-grade AWS infrastructure. It includes:

- A custom VPC with public and private subnets
- NAT Gateways for private subnet internet access
- An Internet Gateway for public subnet internet access
- Application Load Balancer (ALB)
- Auto Scaling Group (ASG) with Launch Template to deploy NGINX
- Security Groups
- A Jump Server (Bastion Host) for SSH access to private instances

Infrastructure Overview
- VPC CIDR: 10.0.0.0/16
- Subnets:
 - Public: 10.0.1.0/24 (us-east-1a), 10.0.2.0/24 (us-east-1b)
 - Private: 10.0.3.0/24 (us-east-1a), 10.0.4.0/24 (us-east-1b)
- NAT Gateways: 2 (1 per AZ)
- Load Balancer: Application Load Balancer (ALB)
- Auto Scaling Group: Deploys NGINX in private subnets
- Jump Server: EC2 instance in public subnet (us-east-1a)

How to Use
1. Prerequisites
- Terraform v1.0+
- An AWS account with appropriate IAM permissions
- An existing SSH key pair (id_ed25519.pub) at:
 ~/.ssh/id_ed25519.pub
> Update the path in aws_key_pair resource if your key is elsewhere.

2. Initialize Terraform
terraform init

3. Review the Plan
terraform plan

4. Apply the Configuration
terraform apply --auto-approve

5. Access the Infrastructure
- Jump Server:
 ssh -i ~/.ssh/id_ed25519 ubuntu@<public_ip>

- Application Load Balancer:
 http://<public_dns>
Security Groups
| Security Group | Description | Ingress Rules |
|----------------|------------------------------|--------------------------------------------|
| load_sg | ALB Security Group | HTTP (80) from anywhere |
| app_sg | App Instances Security Group | HTTP (80) from ALB, SSH (22) from Jump SG |
| jump_sg | Jump Server SG | SSH (22) from anywhere |

Resources Created
- VPC and 4 Subnets
- Internet Gateway and NAT Gateways
- Route Tables and associations
- Application Load Balancer and Target Group
- Launch Template for EC2 with NGINX setup
- Auto Scaling Group
- Jump Server
- Security Groups
Cleanup
To destroy all infrastructure:
terraform destroy --auto-approve

Notes
- All EC2 instances use Amazon Linux 2 (ami-084568db4383264d4/ ubuntu 24.04)
- NGINX is installed via Launch Template user data
- SSH key must exist locally and match the path in the code
Outputs
| Output Name | Description |
|--------------|----------------------------------|
| public_ip | Public IP of the Jump Server |
| public_dns | Public DNS of the Application LB |

if you are seeing "504 badgateway" error while accessing the dns_name, then login to one of the ec2 instance of autoscaling group and check Nginx is running or not.

login process:
1. login to jumpserver you have already copied public key to this instance, so no issue
2. copy the private key and save in one of the file in jump-server
3. use that copied private key to login into the ec2 server of autoscaling group with private key

check ngix is running or with below command:

sudo systemctl status nginx

SSH into your instance, try to manually run:
sudo apt update
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx