# Elastic Beanstalk Deployment Guide

This guide explains how to deploy your Node.js application to AWS Elastic Beanstalk using Docker.

## 📋 Prerequisites

1. **AWS CLI installed and configured**
   ```powershell
   aws --version
   aws sts get-caller-identity
   ```

2. **AWS Credentials with appropriate permissions**
   - Elastic Beanstalk Full Access
   - S3 Access
   - IAM Role Creation (for first-time setup)

3. **Docker** (optional, for local testing)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│  Elastic Beanstalk Environment              │
│  ┌───────────────────────────────────────┐  │
│  │  EC2 Instance (t2.micro)              │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  Docker Container               │  │  │
│  │  │  - Node.js App (Port 3000)      │  │  │
│  │  │  - Mapped to Port 80            │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  Load Balancer (Optional)                   │
│  Auto Scaling (Single Instance)             │
└─────────────────────────────────────────────┘
              ↑
              │
         Deployments
              │
┌─────────────────────────────────────────────┐
│  S3 Bucket                                  │
│  - demo-devops-eb-deployments-{ACCOUNT_ID}  │
│  - Stores application versions              │
└─────────────────────────────────────────────┘
```

## 🚀 Deployment Methods

### Method 1: PowerShell Script (Local)

#### Deploy
```powershell
.\deploy-eb.ps1 -Action deploy
```

#### Check Status
```powershell
.\deploy-eb.ps1 -Action status
```

#### Cleanup Resources
```powershell
.\deploy-eb.ps1 -Action cleanup
```

### Method 2: GitHub Actions (CI/CD)

#### Deploy via Workflow
1. Go to GitHub Actions tab
2. Select "Deploy to Elastic Beanstalk" workflow
3. Click "Run workflow"
4. Select action: `deploy`
5. Click "Run workflow"

#### Cleanup via Workflow
1. Go to GitHub Actions tab
2. Select "Deploy to Elastic Beanstalk" workflow
3. Click "Run workflow"
4. Select action: `cleanup`
5. Click "Run workflow"

#### Auto Deploy on Push
Push to `main` or `master` branch:
```bash
git add .
git commit -m "Deploy to Elastic Beanstalk"
git push origin main
```

### Method 3: EB CLI (Advanced)

#### Install EB CLI
```powershell
pip install awsebcli
```

#### Initialize
```bash
eb init -p docker demo-devops-app --region ap-south-1
```

#### Create Environment
```bash
eb create demo-devops-env
```

#### Deploy
```bash
eb deploy
```

#### Open Application
```bash
eb open
```

## 📁 Key Files

### `.elasticbeanstalk/config.yml`
Configuration file for EB CLI with application and environment settings.

### `Dockerrun.aws.json`
Elastic Beanstalk Docker configuration:
- Defines Docker image to use
- Maps container port 3000 to host port 80
- Configures logging

### `dockerfile`
Docker container definition for your Node.js application.

### `.ebignore`
Specifies files to exclude from deployment package.

### `deploy-eb.ps1`
PowerShell deployment automation script.

## 🔧 Configuration

### Environment Variables
Set environment variables in Elastic Beanstalk:

**Via AWS Console:**
1. Go to Elastic Beanstalk Console
2. Select your environment
3. Configuration → Software → Environment properties
4. Add: `PORT=3000`

**Via CLI:**
```bash
eb setenv PORT=3000
```

### Instance Type
Default: `t2.micro` (Free tier eligible)

To change:
```bash
eb scale 1 --instance-type t3.small
```

### Custom Domain
1. Go to Route 53
2. Create a CNAME record pointing to your EB environment URL
3. Configure in EB Console: Configuration → Load Balancer

## 📊 Monitoring & Logs

### View Logs (EB CLI)
```bash
eb logs
```

### View Logs (AWS Console)
1. Elastic Beanstalk Console
2. Select environment
3. Logs → Request Logs → Last 100 Lines

### Health Monitoring
```bash
eb health
```

### SSH to Instance
```bash
eb ssh
```

## 💰 Cost Estimation

**Monthly costs (ap-south-1 region):**
- EC2 t2.micro (Single Instance): ~$8-10/month
- S3 Storage: ~$0.50/month (for deployment packages)
- Data Transfer: Varies based on traffic

**Free Tier:**
- 750 hours/month of t2.micro (first 12 months)
- 5 GB S3 storage (first 12 months)

## 🔒 Security Best Practices

1. **IAM Roles**: Use instance profiles with minimal required permissions
2. **Security Groups**: Configure proper ingress/egress rules
3. **HTTPS**: Configure SSL certificate for production
4. **Environment Variables**: Store secrets in EB environment properties (encrypted)

## 🐛 Troubleshooting

### Deployment Failed
```powershell
# Check environment health
.\deploy-eb.ps1 -Action status

# View recent events
aws elasticbeanstalk describe-events --application-name demo-devops-app --environment-name demo-devops-env --max-records 20
```

### Application Not Accessible
1. Check Security Group allows inbound traffic on port 80
2. Verify Docker container is running on port 3000
3. Check environment health status

### Docker Container Issues
```bash
# SSH to instance
eb ssh

# Check Docker logs
sudo docker logs $(sudo docker ps -q)

# Check if container is running
sudo docker ps
```

### Permissions Issues
Ensure your IAM user/role has these policies:
- `AWSElasticBeanstalkFullAccess`
- `AmazonS3FullAccess`
- `IAMFullAccess` (for first-time setup)

## 📚 Useful Commands

```powershell
# Get environment URL
aws elasticbeanstalk describe-environments --application-name demo-devops-app --environment-names demo-devops-env --query "Environments[0].CNAME" --output text

# List all environments
aws elasticbeanstalk describe-environments --application-name demo-devops-app

# List application versions
aws elasticbeanstalk describe-application-versions --application-name demo-devops-app

# Update environment
aws elasticbeanstalk update-environment --environment-name demo-devops-env --version-label <VERSION_LABEL>

# Terminate environment
aws elasticbeanstalk terminate-environment --environment-name demo-devops-env
```

## 🔄 Update Strategy

### Rolling Updates (Zero Downtime)
1. Push new code
2. EB creates new instance with new version
3. Health checks pass
4. Old instance terminated
5. New instance serves traffic

### Blue/Green Deployment
```bash
# Clone environment
eb clone demo-devops-env --clone_name demo-devops-env-blue

# Deploy to blue
eb use demo-devops-env-blue
eb deploy

# Swap CNAMEs
eb swap demo-devops-env --destination_name demo-devops-env-blue
```

## 📖 Additional Resources

- [AWS Elastic Beanstalk Documentation](https://docs.aws.amazon.com/elasticbeanstalk/)
- [Docker Platform - Elastic Beanstalk](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/create_deploy_docker.html)
- [EB CLI Documentation](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3.html)

## 🎯 Quick Start

1. **Deploy the application:**
   ```powershell
   .\deploy-eb.ps1 -Action deploy
   ```

2. **Wait for deployment (5-10 minutes)**

3. **Access your application:**
   - URL will be displayed after deployment
   - Format: `http://demo-devops-env.{region}.elasticbeanstalk.com`

4. **When done, cleanup resources:**
   ```powershell
   .\deploy-eb.ps1 -Action cleanup
   ```

## ✅ Success Checklist

- [ ] AWS CLI configured
- [ ] Credentials with proper permissions
- [ ] Reviewed configuration files
- [ ] Ran deployment script
- [ ] Application accessible via URL
- [ ] Logs showing healthy status
- [ ] Environment variables configured
- [ ] Monitoring enabled

---

**Happy Deploying! 🚀**
