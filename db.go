package main

import (
    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/dynamodb"
    "github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
)


// Declare a new DynamoDB instance. 
var db = dynamodb.New(session.New(), aws.NewConfig().WithRegion("replace"))

func getItem(Ksuid string) (*message, error) {
    // Prepare the input for the query.
    input := &dynamodb.GetItemInput{
        TableName: aws.String("replace"), // Replace table name
        Key: map[string]*dynamodb.AttributeValue{
            "Ksuid": {
                S: aws.String(Ksuid),
            },
        },
    }

    // Retrieve the item from DynamoDB. 
    result, err := db.GetItem(input)
    if err != nil {
        return nil, err
    }
    if result.Item == nil {
        return nil, nil
    }

	msg := new(message)


    err = dynamodbattribute.UnmarshalMap(result.Item, msg)
    if err != nil {
        return nil, err
    }

    return msg, nil
}

// Add a message record to DynamoDB.
func putItem(msg *message) error {

    input := &dynamodb.PutItemInput{
        TableName: aws.String("replace"),
        Item: map[string]*dynamodb.AttributeValue{
            "Ksuid": {
                S: aws.String(msg.Ksuid),
            },
            "Message": {
                S: aws.String(msg.Message),
            },
            "User": {
                S: aws.String(msg.User),
            },
            "Date": {
                S: aws.String(msg.Date),
            },
        },
    }

    _, err := db.PutItem(input)
    return err
}