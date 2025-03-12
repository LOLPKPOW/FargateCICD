# Terraform and AWS Fargate with Apache Example
  
This repository is an example of using Terraform, GitHub, and GitHub Actions to create a container on AWS that hosts a simple Apache website.  
  
It does the following:  
  
- Creates a new **VPC**  
- Creates **private subnets** for containers and **public subnets** for Load Balancer and a NAT Gateway  
- Deploys a **NAT Gateway** to allow private subnets to have outbound internet access  
- Deploys an **Application Load Balancer** to route traffic to the containers  
- Creates the **containers** themselves  
- Configures an **auto-scaling group** to scale out containers as needed  
  
The project demonstrates how to automate the creation and deployment of infrastructure using Terraform and manage the deployment of containers with GitHub Actions.  
  
These README instructions assume you can connect to AWS via CLI, create an image using Docker Desktop, can install Terraform, and have some familiarity with GitHub (I mean you're on it right now right!).   
For additional instruction, follow the documentation here:  
For AWS CLI Installation Instruction: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html  
For Terraform Installation Instruction: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli  
For Docker Desktop Installation Instruction: https://www.docker.com/blog/getting-started-with-docker-desktop/  
  
The directories are organized into Terraform files and Container Application files.  
  
You can begin the process by cloning this repository by running `git clone https://github.com/LOLPKPOW/FargateCICD`. This will clone the repository to your current directory.
Feel free to then push this to your own repo, to use it using GitHub Actions!  
  
Next, you can build your Docker Image using the dockerfile in the Container Application folder by running `docker build -t apache-container:latest .`. Or name it something else if you'd like. Feel free to make an ECR Repository for AWS either in the Console, or by running `aws ecr create-repository --repository-name <repository-name> --region <region>` (Make sure to change the repository-name and region!)  
  
You'll need to authenticate to Docker using the following command: `aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com`,   
changing the aws_account_id and region to match. Then tag your image using `docker tag <local-image>:<tag> <aws_account_id>.dkr.ecr.<region>.amazonaws.com/<repository-name>:<tag>`, then  
push it to your repository with `docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/<repository-name>:<tag>`.  
  
In the Terraform folder, there is a "terraform.tfvars.example", where you can fill out your VPC subnet, the multiple private and public subnets, and the location of the docker image in ECR.  
When you make these adjustments, save it without the .example at the end, so Terraform will read it when you run it.  
This might be a good time to check out the .gitignore file. You can see that terraform.tfvars is included in that file, so Git will ignore it when pushing to your repository.  
No need to worry that your information, such as your image repository URL, will be put onto GitHub.  
  
Lets set up our GitHub Actions. If you choose your repository and click the "Actions" tab up top, you should see "Settings". Once you're there, you should see Secrets and Variables -> Actions.  
That's where you can input your AWS Credentials, so GitHub Actions can modify your AWS resources. This repository expects the secrets to be AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, ECR_REPOSITORY, AWS_REGION, and AWS_ACCOUNT_ID.  
The ECR_REPOSITORY is where your container lives in ECR. I.E. containers/apache-project:latest  
The AWS_REGION is simply the region. I.E. us-east-2  
The AWS_ACCOUNT_ID is just your account ID. I.E. 987654321789  
  
If you didn't write them down, but set up your AWS CLI using them, you can find them at C:\Users\YourUserName\.aws\credentials  
The workflow is contained within the .github/workflows/deploy.yml 
  
Next, you can go to where you copied the Terraform folder from my repository, and run `Terraform Plan`. This will show you the proposed infrastructure Terraform will create.  
Assuming you receive no errors (hopefully!), you can run `Terraform Apply -auto-approve` to run the creation without requiring user intervention to approve.  
  
Once it's complete, in the AWS Console you can go to Elastic Container Service -> ApacheCluster -> Find Services and click apache-service -> Click the Tasks tab -> You should see  
your container provisioning/running. You can then go to EC2 -> Load Balancers -> apachealb -> and copy your DNS name from the information. It will look something like `apache-alb-814057752.us-east-2.elb.amazonaws.com`.  
  
You should see the contents of the "index.template.html" file from the Container Application directory. Now, you can just modify that as you'd like, push it to GitHub, and viola! Updated website!