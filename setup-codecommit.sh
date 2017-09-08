#!/bin/bash
#
#========================================================================
#
# DevOps Engineering on AWS - Lab 3: Continuous Integration
#
# This script will set up two IAM users and configure both the Command
# host and the CI Instance with the appropriate SSH parameters to
# enable communication with AWS CodeCommit
#
#========================================================================
# 

clear
echo "This script will perform the steps necessary to setup AWS CodeCommit;"
echo "including provisioning IAM users and uploading SSH keys."
sleep 3 && clear

#========================================================================
#
# Create IAM user and profile for Developer
#
echo "Lets start with developer1 - creating IAM user and CLI profile..."
aws iam create-user --user-name developer1
credentials=$(aws iam create-access-key --user-name developer1 \
   --query 'AccessKey.[AccessKeyId,SecretAccessKey]'  --output text)
access_key_id=$(echo $credentials | cut -d' ' -f 1)
secret_access_key=$(echo $credentials | cut -d' ' -f 2)
aws configure set profile.developer1.aws_access_key_id "$access_key_id"
aws configure set profile.developer1.aws_secret_access_key "$secret_access_key"

# attach IAM policy for CodeCommitFullAccess to developer1
aws iam attach-user-policy --user-name developer1 --policy-arn arn:aws:iam::aws:policy/AWSCodeCommitFullAccess

sleep 5 && clear
echo "developer profile complete.  Time to upload SSH key to IAM and configure local SSH settings."
sleep 5 && clear

# upload ssh key for developer1 user
devPubKeyId=$(aws iam upload-ssh-public-key --user-name developer1 --ssh-public-key-body file:///home/ec2-user/.ssh/id_rsa.pub --query 'SSHPublicKey.SSHPublicKeyId')

# setup ssh config file for AWS CodeCommit
echo "Host git-codecommit.*.amazonaws.com" >> /home/ec2-user/.ssh/config
echo "  User $devPubKeyId" >> /home/ec2-user/.ssh/config
echo "  IdentityFile /home/ec2-user/.ssh/id_rsa" >> /home/ec2-user/.ssh/config
echo "  StrictHostKeyChecking no" >> /home/ec2-user/.ssh/config
chmod 600 /home/ec2-user/.ssh/config

sleep 3 && clear
echo "All finished with developer1.  Lets set up the CI user and EC2 instance now!"
sleep 5 && clear

#=====================================================================
#
# Create IAM user and profile for Continuous Integration platform
#
echo "Creating IAM user for the Continuous Integration platform"
aws iam create-user --user-name ci-user

# Retrieve public key from CI Instance
CiPrivateIp=$(aws cloudformation describe-stacks --stack-name $STACKNAME --query 'Stacks[*].Outputs[?OutputKey == `CIInstancePrivateIP`].OutputValue' --output text)
scp -o StrictHostKeyChecking=no ec2-user@$CiPrivateIp:/home/ec2-user/.ssh/id_rsa.pub /home/ec2-user/.ssh/ci-id_rsa.pub

echo "Connecting to $CiPrivateIp to configure the CI Instance with access to AWS CodeCommit"
sleep 5 && clear

# attach IAM policy for CodeCommitFullAccess to ci-user
aws iam attach-user-policy --user-name ci-user --policy-arn arn:aws:iam::aws:policy/AWSCodeCommitFullAccess

# upload ssh key for ci-user
ciPubKeyId=$(aws iam upload-ssh-public-key --user-name ci-user --ssh-public-key-body file:///home/ec2-user/.ssh/ci-id_rsa.pub --query 'SSHPublicKey.SSHPublicKeyId')

# setup ssh config file for AWS CodeCommit
echo "Host git-codecommit.*.amazonaws.com" >> /home/ec2-user/.ssh/ci-config
echo "  User $ciPubKeyId" >> /home/ec2-user/.ssh/ci-config
echo "  IdentityFile /var/lib/jenkins/.ssh/id_rsa" >> /home/ec2-user/.ssh/ci-config
echo "  StrictHostKeyChecking no" >> /home/ec2-user/.ssh/ci-config
chmod 600 /home/ec2-user/.ssh/ci-config

# place ssh config file on CI instance and set permissions accordingly
scp -o StrictHostKeyChecking=no /home/ec2-user/.ssh/ci-config ec2-user@$CiPrivateIp:/home/ec2-user/config
ssh ec2-user@$CiPrivateIp -t 'sudo mv /home/ec2-user/config /var/lib/jenkins/.ssh/config'
ssh ec2-user@$CiPrivateIp -t 'sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh/'

sleep 3 && clear
echo "Configuration for ci-user complete.  The setup script will now exit."
sleep 5 && clear

# Set as default profile
echo "export AWS_DEFAULT_PROFILE=developer1" >> ~/.bash_profile
export AWS_DEFAULT_PROFILE=developer1

