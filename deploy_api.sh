#!/bin/bash

#
# Created by: David Sensibaugh
#

main () {

echo "Enter Lambda function name: " && read lambda_name

###################################
# Check configuration
###################################
account=`aws sts get-caller-identity --query Account --output text`
verify_configuration $account "account"

region=`aws configure get region`
verify_configuration $region "region"

echo -e "\nUsing accout: $account"
echo "Using region: $region"

###################################
# Modify db.go to match region and table name
###################################
sed -i.bak "s/TableName:.aws.String(\"replace\")/TableName: aws.String(\"$lambda_name\")/g; s/WithRegion(\"replace\")/WithRegion(\"$region\")/g;" db.go && rm db.go.bak


###################################
# Download packages
###################################
echo -e "\n-- Downloading packages --\n"
go get -v -u ./...


###################################
# Create Lambda role
###################################
lambda_role="lambda-$lambda_name-executor"

echo -e "\n-- Creating role: $lambda_role and attaching policies: AWSLambdaBasicExecutionRole, dynamodb-item-crud-role --\n"
aws iam create-role --role-name $lambda_role \
	--assume-role-policy-document file://./tmp/trust-policy.json > /dev/null

aws iam attach-role-policy --role-name $lambda_role \
	--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole > /dev/null

aws iam put-role-policy --role-name $lambda_role \
	--policy-name dynamodb-item-crud-role \
	--policy-document file://./tmp/privilege-policy.json > /dev/null


###################################
# Build project and deploy Lambda
###################################
echo -e "\n-- Building and deploying Lambda --\n"
env GOOS=linux GOARCH=amd64 go build -o ./tmp/main "go-api-gateway"

zip -j ./tmp/main.zip ./tmp/main

aws lambda create-function --function-name $lambda_name --runtime go1.x \
	--role arn:aws:iam::$account:role/$lambda_role \
	--handler main --zip-file fileb://./tmp/main.zip > /dev/null


###################################
# Create DynamoDB table
###################################
echo -e "\n-- Creating DynamoDB table --\n"
aws dynamodb create-table --table-name $lambda_name \
	--attribute-definitions AttributeName=Ksuid,AttributeType=S \
	--key-schema AttributeName=Ksuid,KeyType=HASH \
	--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 > /dev/null


###################################
# Create API Gateway
###################################
echo -e "\n-- Creating API Gateway --\n"

rest_api_id=`aws apigateway create-rest-api --name $lambda_name --query id --output text`
root_path_id=`aws apigateway get-resources --rest-api-id $rest_api_id --query 'items[0].id' --output text`
resource_id=`aws apigateway create-resource --rest-api-id $rest_api_id --parent-id $root_path_id --path-part messages --query id --output text`

echo "Gateway rest API id: $rest_api_id"
echo "Root path id: $root_path_id"
echo "Resource id: $resource_id"

aws apigateway put-method --rest-api-id $rest_api_id \
	--resource-id $resource_id --http-method ANY \
	--authorization-type NONE > /dev/null

aws apigateway put-integration --rest-api-id $rest_api_id \
	--resource-id $resource_id --http-method ANY --type AWS_PROXY \
	--integration-http-method POST \
	--uri "arn:aws:apigateway:$region:lambda:path/2015-03-31/functions/arn:aws:lambda:$region:$account:function:$lambda_name/invocations" > /dev/null


###################################
# Add Lambda Permissions
###################################
echo -e "\n-- Adding Lambda permissions --\n"

aws lambda add-permission --function-name $lambda_name \
	--statement-id 54b07cc1-f4cf-4f47-9b41-928ef175f515 \
	--action lambda:InvokeFunction --principal apigateway.amazonaws.com \
	--source-arn "arn:aws:execute-api:$region:$account:$rest_api_id/*/*/*" > /dev/null


###################################
# Create deployment
###################################
stage="staging"

echo "Creating $stage deployment"
aws apigateway create-deployment --rest-api-id $rest_api_id --stage-name $stage > /dev/null


###################################
# Test info
###################################
echo "API Gateway invoke url: https://$rest_api_id.execute-api.$region.amazonaws.com/$stage/messages"
echo "Test POST:"
echo "curl -i -H \"Content-Type: application/json\" -X POST \
	-d '{\"User\":\"TestUser\", \"Message\": \"Test Message\"}' \
	https://$rest_api_id.execute-api.$region.amazonaws.com/$stage/messages  | grep Ksuid | cut -d "=" -f2"

echo -e "\nTest GET:"
echo "aws apigateway test-invoke-method --rest-api-id <Rest API id> \
	--resource-id <Resource id> --http-method \"GET\" \
	--path-with-query-string \"/messages?ksuid=<KSUID>\""

}

verify_configuration () {

	if [ -z "$1" ]
	then
        	echo "Please configure AWS CLI $2 before running deploy_api.sh"
        	exit 1
	fi
}


main "$@"

