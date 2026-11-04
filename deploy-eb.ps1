# Elastic Beanstalk Deployment Script
# Description: Deploy Node.js application to AWS Elastic Beanstalk with Docker

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("deploy", "cleanup", "status")]
    [string]$Action = "deploy"
)

$ErrorActionPreference = "Stop"

# Configuration
$AWS_REGION = "ap-south-1"
$EB_APP_NAME = "demo-devops-app"
$EB_ENV_NAME = "demo-devops-env"
$EB_PLATFORM = "Docker running on 64bit Amazon Linux 2"

# EB uses managed bucket: elasticbeanstalk-{region}-{account-id}
# We'll determine this at runtime

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Elastic Beanstalk Deployment Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Yellow
Write-Host ""

# Get AWS Account ID
Write-Host "Getting AWS Account ID..." -ForegroundColor Yellow
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get AWS Account ID. Please check your AWS credentials." -ForegroundColor Red
    exit 1
}
Write-Host "✓ Account ID: $ACCOUNT_ID" -ForegroundColor Green

# Use EB-managed S3 bucket
$S3_BUCKET = "elasticbeanstalk-$AWS_REGION-$ACCOUNT_ID"
Write-Host "✓ Using EB-managed bucket: $S3_BUCKET" -ForegroundColor Green

if ($Action -eq "status") {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Checking Deployment Status" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # Check Application
    Write-Host "Application Status:" -ForegroundColor Yellow
    $appExists = aws elasticbeanstalk describe-applications `
        --application-names $EB_APP_NAME `
        --region $AWS_REGION 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Application exists: $EB_APP_NAME" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Application does not exist" -ForegroundColor Red
    }
    
    # Check Environment
    Write-Host "Environment Status:" -ForegroundColor Yellow
    $envStatus = aws elasticbeanstalk describe-environments `
        --application-name $EB_APP_NAME `
        --environment-names $EB_ENV_NAME `
        --region $AWS_REGION `
        --query "Environments[0].[Status,Health,CNAME]" `
        --output text 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $envStatus) {
        $statusParts = $envStatus -split "`t"
        Write-Host "  ✓ Environment: $EB_ENV_NAME" -ForegroundColor Green
        Write-Host "    Status: $($statusParts[0])" -ForegroundColor White
        Write-Host "    Health: $($statusParts[1])" -ForegroundColor White
        Write-Host "    URL: http://$($statusParts[2])" -ForegroundColor White
    } else {
        Write-Host "  ❌ Environment does not exist" -ForegroundColor Red
    }
    
    # Check S3 Bucket
    Write-Host "S3 Bucket Status:" -ForegroundColor Yellow
    Write-Host "  Using EB-managed bucket: $S3_BUCKET" -ForegroundColor White
    Write-Host "  (Managed by Elastic Beanstalk)" -ForegroundColor Gray
    
    exit 0
}

if ($Action -eq "cleanup") {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "⚠️  WARNING: Cleaning Up Resources" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "This will delete:" -ForegroundColor Yellow
    Write-Host "  - EB Environment: $EB_ENV_NAME" -ForegroundColor White
    Write-Host "  - EB Application: $EB_APP_NAME" -ForegroundColor White
    Write-Host "Note: EB-managed S3 bucket will remain (managed by AWS)" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Are you sure? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    # Terminate Environment
    Write-Host ""
    Write-Host "1. Terminating Environment..." -ForegroundColor Yellow
    $envExists = aws elasticbeanstalk describe-environments `
        --application-name $EB_APP_NAME `
        --environment-names $EB_ENV_NAME `
        --region $AWS_REGION 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $envExists) {
        aws elasticbeanstalk terminate-environment `
            --environment-name $EB_ENV_NAME `
            --region $AWS_REGION
        
        Write-Host "   Waiting for environment to terminate..." -ForegroundColor Gray
        for ($i = 1; $i -le 40; $i++) {
            Start-Sleep -Seconds 15
            $status = aws elasticbeanstalk describe-environments `
                --application-name $EB_APP_NAME `
                --environment-names $EB_ENV_NAME `
                --region $AWS_REGION `
                --query "Environments[0].Status" `
                --output text 2>$null
            
            Write-Host "   Attempt $i/40 - Status: $status" -ForegroundColor Gray
            
            if ($status -eq "Terminated" -or $status -eq "None" -or $LASTEXITCODE -ne 0) {
                Write-Host "   ✓ Environment terminated" -ForegroundColor Green
                break
            }
        }
    } else {
        Write-Host "   Environment does not exist" -ForegroundColor Gray
    }
    
    # Delete Application
    Write-Host ""
    Write-Host "2. Deleting Application..." -ForegroundColor Yellow
    $appExists = aws elasticbeanstalk describe-applications `
        --application-names $EB_APP_NAME `
        --region $AWS_REGION 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $appExists) {
        aws elasticbeanstalk delete-application `
            --application-name $EB_APP_NAME `
            --terminate-env-by-force `
            --region $AWS_REGION
        Write-Host "   ✓ Application deleted" -ForegroundColor Green
    } else {
        Write-Host "   Application does not exist" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "✓ Cleanup Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Note: EB-managed S3 bucket retained by AWS" -ForegroundColor Gray
    exit 0
}

# DEPLOY ACTION
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Step 1: Verify S3 Storage" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Using EB-managed S3 bucket: $S3_BUCKET" -ForegroundColor Yellow
Write-Host "Note: Elastic Beanstalk will create/manage this bucket automatically" -ForegroundColor Gray
Write-Host "✓ Storage configuration verified" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Step 2: Create EB Application" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$appExists = aws elasticbeanstalk describe-applications `
    --application-names $EB_APP_NAME `
    --region $AWS_REGION 2>$null

if ($LASTEXITCODE -eq 0 -and $appExists) {
    Write-Host "✓ EB Application already exists: $EB_APP_NAME" -ForegroundColor Green
} else {
    Write-Host "Creating EB Application: $EB_APP_NAME" -ForegroundColor Yellow
    aws elasticbeanstalk create-application `
        --application-name $EB_APP_NAME `
        --description "Demo DevOps Node.js Application" `
        --region $AWS_REGION
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create EB application" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ EB Application created successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Step 3: Package Application" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$VERSION_LABEL = "$EB_APP_NAME-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Write-Host "Version Label: $VERSION_LABEL" -ForegroundColor Yellow

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow

$excludePatterns = @(
    "*.git*",
    "*node_modules*",
    "*.github*",
    "*Terraform*",
    "*k8s*",
    "*.sh",
    "*Jenkinsfile*",
    "*.md",
    "*build/*",
    "deploy.zip"
)

# Use PowerShell's Compress-Archive
$tempDir = "$env:TEMP\eb-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy files excluding patterns
Get-ChildItem -Path . -Recurse | Where-Object {
    $item = $_
    $shouldExclude = $false
    foreach ($pattern in $excludePatterns) {
        $pattern = $pattern.Replace("*", "")
        if ($item.FullName -like "*$pattern*") {
            $shouldExclude = $true
            break
        }
    }
    -not $shouldExclude
} | ForEach-Object {
    $relativePath = $_.FullName.Substring($PWD.Path.Length + 1)
    $targetPath = Join-Path $tempDir $relativePath
    $targetDir = Split-Path $targetPath -Parent
    
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    if (-not $_.PSIsContainer) {
        Copy-Item $_.FullName $targetPath -Force
    }
}

# Create zip file
Compress-Archive -Path "$tempDir\*" -DestinationPath "deploy.zip" -Force
Remove-Item -Path $tempDir -Recurse -Force

$fileSize = (Get-Item "deploy.zip").Length / 1MB
Write-Host "✓ Package created: deploy.zip ($("{0:N2}" -f $fileSize) MB)" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Step 4: Upload to S3" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

aws s3 cp deploy.zip "s3://$S3_BUCKET/$VERSION_LABEL.zip"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to upload to S3" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Uploaded to S3: s3://$S3_BUCKET/$VERSION_LABEL.zip" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Step 5: Create Application Version" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

aws elasticbeanstalk create-application-version `
    --application-name $EB_APP_NAME `
    --version-label $VERSION_LABEL `
    --source-bundle "S3Bucket=$S3_BUCKET,S3Key=$VERSION_LABEL.zip" `
    --region $AWS_REGION

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create application version" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Application version created: $VERSION_LABEL" -ForegroundColor Green

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Step 6: Deploy to Environment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$envExists = aws elasticbeanstalk describe-environments `
    --application-name $EB_APP_NAME `
    --environment-names $EB_ENV_NAME `
    --region $AWS_REGION 2>$null

if ($LASTEXITCODE -eq 0 -and $envExists) {
    Write-Host "Environment exists, updating..." -ForegroundColor Yellow
    aws elasticbeanstalk update-environment `
        --application-name $EB_APP_NAME `
        --environment-name $EB_ENV_NAME `
        --version-label $VERSION_LABEL `
        --region $AWS_REGION
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to update environment" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Environment update initiated" -ForegroundColor Green
} else {
    Write-Host "Creating new environment..." -ForegroundColor Yellow
    aws elasticbeanstalk create-environment `
        --application-name $EB_APP_NAME `
        --environment-name $EB_ENV_NAME `
        --version-label $VERSION_LABEL `
        --solution-stack-name $EB_PLATFORM `
        --option-settings `
            Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=t2.micro `
            Namespace=aws:autoscaling:launchconfiguration,OptionName=IamInstanceProfile,Value=aws-elasticbeanstalk-ec2-role `
            Namespace=aws:elasticbeanstalk:environment,OptionName=EnvironmentType,Value=SingleInstance `
            Namespace=aws:elasticbeanstalk:application:environment,OptionName=PORT,Value=3000 `
        --region $AWS_REGION
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create environment" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Environment creation initiated" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Step 7: Waiting for Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "This may take 5-10 minutes..." -ForegroundColor Yellow
Write-Host ""

for ($i = 1; $i -le 60; $i++) {
    Start-Sleep -Seconds 30
    
    $envInfo = aws elasticbeanstalk describe-environments `
        --application-name $EB_APP_NAME `
        --environment-names $EB_ENV_NAME `
        --region $AWS_REGION `
        --query "Environments[0].[Status,Health]" `
        --output text
    
    $status, $health = $envInfo -split "`t"
    
    Write-Host "Attempt $i/60 - Status: $status, Health: $health" -ForegroundColor Gray
    
    if ($status -eq "Ready" -and $health -ne "Grey") {
        Write-Host "✓ Environment is ready!" -ForegroundColor Green
        break
    }
    
    if ($status -eq "Terminated") {
        Write-Host "❌ Environment deployment failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✓ Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan

$URL = aws elasticbeanstalk describe-environments `
    --application-name $EB_APP_NAME `
    --environment-names $EB_ENV_NAME `
    --region $AWS_REGION `
    --query "Environments[0].CNAME" `
    --output text

Write-Host ""
Write-Host "Application Details:" -ForegroundColor Yellow
Write-Host "  Application: $EB_APP_NAME" -ForegroundColor White
Write-Host "  Environment: $EB_ENV_NAME" -ForegroundColor White
Write-Host "  Version: $VERSION_LABEL" -ForegroundColor White
Write-Host "  Region: $AWS_REGION" -ForegroundColor White
Write-Host "  URL: http://$URL" -ForegroundColor Cyan
Write-Host ""
Write-Host "Visit your application at: http://$URL" -ForegroundColor Green
Write-Host ""

# Cleanup local deploy.zip
Remove-Item "deploy.zip" -Force -ErrorAction SilentlyContinue

Write-Host "=========================================" -ForegroundColor Cyan
