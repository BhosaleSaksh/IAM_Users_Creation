#!/bin/bash
# IAM User Creation Script with Group Assignment

# Variables
ACCOUNT_ALIAS="cloudverse2k25"
USER_PREFIX="cv25user"
NUM_USERS=15
GROUP_NAME="TechFusion2k25"
OUTPUT_FILE="iam_users_credentials.csv"

# Create CSV file header
echo "Username,Password,AccessKeyID,SecretAccessKey" > $OUTPUT_FILE

# Create group if it doesn't exist
aws iam get-group --group-name $GROUP_NAME 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Creating IAM group: $GROUP_NAME"
    aws iam create-group --group-name $GROUP_NAME

    # Attach policies to the group
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
    aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AWSCloudShellFullAccess
fi

# Create users and add them to the group
for i in $(seq 1 $NUM_USERS); do
    USERNAME="${USER_PREFIX}${i}"
    PASSWORD=$(openssl rand -base64 12)

    echo "Creating IAM user: $USERNAME"

    # Create user
    aws iam create-user --user-name $USERNAME

    # Create login profile (console password)
    aws iam create-login-profile \
        --user-name $USERNAME \
        --password "$PASSWORD"

    # Add user to the group
    aws iam add-user-to-group --user-name $USERNAME --group-name $GROUP_NAME

    # Create access keys
    KEYS=$(aws iam create-access-key --user-name $USERNAME)

    ACCESS_KEY_ID=$(echo $KEYS | jq -r '.AccessKey.AccessKeyId')
    SECRET_ACCESS_KEY=$(echo $KEYS | jq -r '.AccessKey.SecretAccessKey')

    # Save credentials to file
    echo "$USERNAME,$PASSWORD,$ACCESS_KEY_ID,$SECRET_ACCESS_KEY" >> $OUTPUT_FILE
done

echo "✅ IAM users created, added to group $GROUP_NAME, and credentials saved in $OUTPUT_FILE"

