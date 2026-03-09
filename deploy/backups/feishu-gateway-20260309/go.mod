module github.com/chancejiang/zeroclaw/feishu-gateway

go 1.21

// Use local SDK fork from git@github.com:chancefcc/oapi-sdk-go.git
replace github.com/larksuite/oapi-sdk-go/v3 => ./sdk

require (
	github.com/joho/godotenv v1.5.1
	github.com/larksuite/oapi-sdk-go/v3 v3.0.0
)

require (
	github.com/gogo/protobuf v1.3.2 // indirect
	github.com/gorilla/websocket v1.5.0 // indirect
)
