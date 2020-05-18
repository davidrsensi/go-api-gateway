package main

import (
	"encoding/json"
    "log"
    "net/http"
    "os"
    "regexp"
    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
    "fmt"
	"github.com/segmentio/ksuid"
	"time"

)

var ksuidRegexp = regexp.MustCompile(`\w{27}$`)
var errorLogger = log.New(os.Stderr, "ERROR ", log.Llongfile)

type message struct {
    Ksuid   string `json:"ksuid"`
    User  	string `json:"user"`
	Message string `json:"message"`
	Date 	string `json:"date"`
}


type PostMessage struct {
    User  	string `json:"user"`
	Message string `json:"message"`
}


func router(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
    switch req.HTTPMethod {
    case "GET":
        return get(req)
    case "POST":
        return create(req)
    default:
        return clientError(http.StatusMethodNotAllowed)
    }
}

func get(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {

	ksuid := req.QueryStringParameters["ksuid"]
    if !ksuidRegexp.MatchString(ksuid) {
        return clientError(http.StatusBadRequest)
    }

	msg, err := getItem(ksuid)

	if err != nil {
        return serverError(err)
    }
    if msg == nil {
        return clientError(http.StatusNotFound)
    }
	
    js, err := json.Marshal(msg)
    if err != nil {
        return serverError(err)
    }

    // Return a response with a 200 OK status and the JSON message record as the body.
    return events.APIGatewayProxyResponse{
        StatusCode: http.StatusOK,
        Body:       string(js),
    }, nil
}


func create(req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) { 
    // if req.Headers["content-type"] == "application/json" && req.Headers["Content-Type"] == "application/json" {
    //     return clientError(http.StatusNotAcceptable)
    // }

    postMsg := new(PostMessage)
    err := json.Unmarshal([]byte(req.Body), postMsg)
    if err != nil {
        return clientError(http.StatusUnprocessableEntity)
    }

    if postMsg.User == "" || postMsg.Message == "" {
        return clientError(http.StatusBadRequest)
    }

    msg := new(message)

    msg.Ksuid = ksuid.New().String()
    msg.Date = time.Now().Format("20060102150405")
    msg.User = postMsg.User
    msg.Message = postMsg.Message

    err = putItem(msg)
    if err != nil {
        return serverError(err)
    }

    return events.APIGatewayProxyResponse{
        StatusCode: 201,
        Headers:    map[string]string{"Location": fmt.Sprintf("/messages?Ksuid=%s", msg.Ksuid)},
    }, nil
}


func serverError(err error) (events.APIGatewayProxyResponse, error) {
    errorLogger.Println(err.Error())

    return events.APIGatewayProxyResponse{
        StatusCode: http.StatusBadRequest,
        Body:       http.StatusText(http.StatusBadRequest),
    }, nil
}


func clientError(status int) (events.APIGatewayProxyResponse, error) {
    return events.APIGatewayProxyResponse{
        StatusCode: status,
        Body:       http.StatusText(status),
    }, nil
}


func main() {
    lambda.Start(router)
}