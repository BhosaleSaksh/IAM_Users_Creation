#!/bin/bash
USER_PREFIX="cv25user"
NUM_USERS=15
GROUP_NAME="TechFusion2k25"

for i in $(seq 1 $NUM_USERS); do
    USERNAME="${USER_PREFIX}${i}"
    echo "🔹 Cleaning up resources for IAM user: $USERNAME"

    # ------------------------------
    # Delete EC2 instances created by this user (tagged Owner=$USERNAME)
    # ------------------------------
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:Owner,Values=$USERNAME" \
        --query "Reservations[].Instances[].InstanceId" --output text)

    if [ ! -z "$INSTANCE_IDS" ]; then
        echo "Deleting EC2 instances: $INSTANCE_IDS"
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
    fi

    # ------------------------------
    # Delete S3 buckets created by this user (name contains username)
    # ------------------------------
    BUCKETS=$(aws s3api list-buckets --query "Buckets[?contains(Name, '$USERNAME')].Name" --output text)
    for bucket in $BUCKETS; do
        echo "Deleting S3 bucket: $bucket"
        aws s3 rb "s3://$bucket" --force
    done

    # ------------------------------
    # Delete Lambda functions created by this user (name contains username)
    # ------------------------------
    LAMBDAS=$(aws lambda list-functions --query "Functions[?contains(FunctionName, '$USERNAME')].FunctionName" --output text)
    for fn in $LAMBDAS; do
        echo "Deleting Lambda function: $fn"
        aws lambda delete-function --function-name $fn
    done

    # ------------------------------
    # Delete RDS instances created by this user (identifier contains username)
    # ------------------------------
    RDS_INSTANCES=$(aws rds describe-db-instances \
        --query "DBInstances[?contains(DBInstanceIdentifier, '$USERNAME')].DBInstanceIdentifier" --output text)
    for db in $RDS_INSTANCES; do
        echo "Deleting RDS instance: $db"
        aws rds delete-db-instance --db-instance-identifier $db --skip-final-snapshot
    done

    # ------------------------------
    # Delete DynamoDB tables created by this user (name contains username)
    # ------------------------------
    TABLES=$(aws dynamodb list-tables --query "TableNames[?contains(@, '$USERNAME')]" --output text)
    for table in $TABLES; do
        echo "Deleting DynamoDB table: $table"
        aws dynamodb delete-table --table-name $table
    done

    # ------------------------------
    # Delete VPCs created by this user (tagged Owner=$USERNAME)
    # ------------------------------
    VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Owner,Values=$USERNAME" \
        --query "Vpcs[].VpcId" --output text)
    for vpc in $VPCS; do
        echo "Deleting VPC: $vpc"
        SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query "Subnets[].SubnetId" --output text)
        for subnet in $SUBNETS; do
            aws ec2 delete-subnet --subnet-id $subnet
        done

        IGWS=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc" --query "InternetGateways[].InternetGatewayId" --output text)
        for igw in $IGWS; do
            aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $vpc
            aws ec2 delete-internet-gateway --internet-gateway-id $igw
        done

        RTBS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc" --query "RouteTables[].RouteTableId" --output text)
        for rtb in $RTBS; do
            aws ec2 delete-route-table --route-table-id $rtb
        done

        aws ec2 delete-vpc --vpc-id $vpc
    done

    # ------------------------------
    # Delete IAM user resources
    # ------------------------------
    echo "Deleting IAM resources for $USERNAME"

    # Remove user from all groups
    for group in $(aws iam list-groups-for-user --user-name $USERNAME --query 'Groups[].GroupName' --output text); do
        echo "Removing $USERNAME from group $group"
        aws iam remove-user-from-group --user-name $USERNAME --group-name $group
    done

    # Delete login profile
    aws iam delete-login-profile --user-name $USERNAME 2>/dev/null

    # Delete access keys
    for key in $(aws iam list-access-keys --user-name $USERNAME --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
        aws iam delete-access-key --user-name $USERNAME --access-key-id $key
    done

    # Detach all attached policies
    for policy in $(aws iam list-attached-user-policies --user-name $USERNAME --query 'AttachedPolicies[].PolicyArn' --output text); do
        aws iam detach-user-policy --user-name $USERNAME --policy-arn $policy
    done

    # Delete the user
    aws iam delete-user --user-name $USERNAME

    echo "✅ Cleanup completed for $USERNAME"
done

echo "🎉 All users and their resources have been deleted."

