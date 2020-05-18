## go-api-gateway
This project is a simple Golang API that utilizes AWS Lambda, API Gateway, and DynamoDB. Use the deploy_api.sh script to quickly deploy the API.

### Prerequisite:
- Have AWS CLI installed and configured (preferably with an account that has admin access).
- deploy_api.sh requires Bash.
- Golang must be installed.

### Deploy Instructions:
```
cd $GOPATH/src
git clone git@github.com:davidrsensi/go-api-gateway.git
cd go-api-gateway
./deploy_api.sh
```
### Test the API:
Test POST:
```
curl -i -H "Content-Type: application/json" -X POST \
    -d '{"User":"Post User", "Message": "Test Message"}' \
    https://<rest API id>.execute-api.<region>.amazonaws.com/<stage>/messages
```

Test GET:
```
aws apigateway test-invoke-method --rest-api-id <rest API id> --resource-id <resource id> \
    --http-method "GET" --path-with-query-string "/messages?ksuid=<KSUID>"
```