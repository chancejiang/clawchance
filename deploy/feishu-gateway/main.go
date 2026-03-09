package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	"unicode/utf8"

	"github.com/joho/godotenv"
	lark "github.com/larksuite/oapi-sdk-go/v3"
	larkcore "github.com/larksuite/oapi-sdk-go/v3/core"
	"github.com/larksuite/oapi-sdk-go/v3/event/dispatcher"
	larkim "github.com/larksuite/oapi-sdk-go/v3/service/im/v1"
	larkws "github.com/larksuite/oapi-sdk-go/v3/ws"
)

// Configuration holds app configuration
type Config struct {
	AppID           string
	AppSecret       string
	ZeroClawWebhook string
	LogLevel        larkcore.LogLevel
}

// ZeroClawRequest represents a request to ZeroClaw
type ZeroClawRequest struct {
	Message   string `json:"message"`
	UserID    string `json:"user_id,omitempty"`
	ChatID    string `json:"chat_id,omitempty"`
	MessageID string `json:"message_id,omitempty"`
}

// ZeroClawResponse represents a response from ZeroClaw
type ZeroClawResponse struct {
	Response string `json:"response"`
	Error    string `json:"error,omitempty"`
}

// FeishuGateway handles Feishu integration
type FeishuGateway struct {
	config      *Config
	wsClient    *larkws.Client
	apiClient   *lark.Client
	zeroclawURL string
	httpClient  *http.Client
}

// LoadConfig loads configuration from environment variables
func LoadConfig() *Config {
	// Load .env file if it exists
	_ = godotenv.Load()

	logLevel := larkcore.LogLevelInfo
	if os.Getenv("LOG_LEVEL") == "debug" {
		logLevel = larkcore.LogLevelDebug
	}

	return &Config{
		AppID:           os.Getenv("FEISHU_APP_ID"),
		AppSecret:       os.Getenv("FEISHU_APP_SECRET"),
		ZeroClawWebhook: getEnv("ZEROCLAW_WEBHOOK_URL", "http://127.0.0.1:42617/webhook"),
		LogLevel:        logLevel,
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// NewFeishuGateway creates a new FeishuGateway instance
func NewFeishuGateway(config *Config) *FeishuGateway {
	gateway := &FeishuGateway{
		config:      config,
		zeroclawURL: config.ZeroClawWebhook,
		httpClient: &http.Client{
			Timeout: 120 * time.Second, // 2 minutes for long AI responses
		},
	}

	// Create API client for sending messages
	gateway.apiClient = lark.NewClient(config.AppID, config.AppSecret,
		lark.WithLogLevel(config.LogLevel),
	)

	return gateway
}

// handleMessage handles incoming Feishu messages
func (g *FeishuGateway) handleMessage(ctx context.Context, event *larkim.P2MessageReceiveV1) error {
	// Validate event structure
	if event.Event == nil || event.Event.Message == nil {
		return fmt.Errorf("invalid event structure: missing Event or Message")
	}

	// Safely extract message fields with nil checks
	if event.Event.Message.MessageId == nil || event.Event.Message.ChatId == nil ||
		event.Event.Message.MessageType == nil || event.Event.Message.Content == nil {
		return fmt.Errorf("message missing required fields")
	}

	messageID := *event.Event.Message.MessageId
	chatID := *event.Event.Message.ChatId
	msgType := *event.Event.Message.MessageType
	content := *event.Event.Message.Content

	// Get sender ID (prefer OpenId as it's always present, UserId can be nil)
	var senderID string = "unknown"
	if event.Event.Sender != nil && event.Event.Sender.SenderId != nil {
		if event.Event.Sender.SenderId.UserId != nil {
			senderID = *event.Event.Sender.SenderId.UserId
		} else if event.Event.Sender.SenderId.OpenId != nil {
			senderID = *event.Event.Sender.SenderId.OpenId
		} else if event.Event.Sender.SenderId.UnionId != nil {
			senderID = *event.Event.Sender.SenderId.UnionId
		}
	}

	log.Printf("📩 [Message] Chat: %s, Sender: %s, Type: %s", chatID, senderID, msgType)

	// Only handle text messages
	if msgType != "text" {
		log.Printf("⏭️  Skipping non-text message type: %s", msgType)
		return nil
	}

	// Parse text content
	var textContent struct {
		Text string `json:"text"`
	}
	if err := json.Unmarshal([]byte(content), &textContent); err != nil {
		log.Printf("❌ Failed to parse message content: %v", err)
		return fmt.Errorf("failed to parse message content: %w", err)
	}

	userMessage := textContent.Text
	log.Printf("💬 User message: %s", userMessage)

	// Forward to ZeroClaw for AI processing
	aiResponse, err := g.callZeroClaw(ctx, userMessage, senderID, chatID, messageID)
	if err != nil {
		log.Printf("❌ ZeroClaw error: %v", err)
		aiResponse = fmt.Sprintf("🦀 [ZeroClaw Error]: %v", err)
	}

	log.Printf("🦀 ZeroClaw response: %s", truncate(aiResponse, 100))

	// Reply to the message
	if err := g.replyMessage(ctx, messageID, aiResponse); err != nil {
		log.Printf("❌ Failed to reply: %v", err)
		return fmt.Errorf("failed to reply: %w", err)
	}

	log.Printf("✅ Replied to message: %s", messageID)
	return nil
}

// callZeroClaw calls the ZeroClaw webhook for AI processing
func (g *FeishuGateway) callZeroClaw(ctx context.Context, message, userID, chatID, messageID string) (string, error) {
	reqBody := ZeroClawRequest{
		Message:   message,
		UserID:    userID,
		ChatID:    chatID,
		MessageID: messageID,
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", g.zeroclawURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to call ZeroClaw: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("ZeroClaw returned status %d", resp.StatusCode)
	}

	var result ZeroClawResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	if result.Error != "" {
		return "", fmt.Errorf("ZeroClaw error: %s", result.Error)
	}

	return result.Response, nil
}

// sanitizeContent sanitizes text content for Feishu API
// Removes or replaces characters that may cause API errors
func sanitizeContent(text string) string {
	// Remove null bytes and other control characters except newlines and tabs
	var result strings.Builder
	for _, r := range text {
		if r == 0x00 || (r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D) {
			// Skip null bytes and control characters except tab, newline, carriage return
			continue
		}
		result.WriteRune(r)
	}
	sanitized := result.String()

	// Trim leading/trailing whitespace
	sanitized = strings.TrimSpace(sanitized)

	// Feishu text message limit is 30KB (about 10000 Chinese characters or 30000 ASCII)
	// We'll limit to 28000 bytes to be safe
	const maxBytes = 28000
	if utf8.RuneCountInString(sanitized) > maxBytes/3 { // Rough estimate
		byteLen := len([]byte(sanitized))
		if byteLen > maxBytes {
			// Truncate to maxBytes, respecting UTF-8 boundaries
			bytes := []byte(sanitized)
			for len(bytes) > maxBytes {
				// Remove last rune
				_, size := utf8.DecodeLastRune(bytes)
				bytes = bytes[:len(bytes)-size]
			}
			sanitized = string(bytes) + "\n... (message truncated)"
		}
	}

	return sanitized
}

// replyMessage sends a reply to a Feishu message
func (g *FeishuGateway) replyMessage(ctx context.Context, messageID, text string) error {
	// Sanitize content to prevent API errors
	sanitizedText := sanitizeContent(text)

	// Log if text was modified
	if sanitizedText != text {
		log.Printf("⚠️  Content was sanitized (original: %d bytes, sanitized: %d bytes)",
			len(text), len(sanitizedText))
	}

	// Debug log the content being sent
	log.Printf("📤 Sending reply content (first 200 chars): %s", truncate(sanitizedText, 200))

	// Build text content using raw JSON to ensure proper escaping
	contentBytes, err := json.Marshal(map[string]string{"text": sanitizedText})
	if err != nil {
		return fmt.Errorf("failed to marshal content: %w", err)
	}
	content := string(contentBytes)

	// Debug log the JSON content
	log.Printf("📤 JSON content length: %d bytes", len(content))

	// Reply to message
	resp, err := g.apiClient.Im.Message.Reply(ctx,
		larkim.NewReplyMessageReqBuilder().
			MessageId(messageID).
			Body(larkim.NewReplyMessageReqBodyBuilder().
				MsgType(larkim.MsgTypeText).
				Content(content).
				Build()).
			Build())

	if err != nil {
		log.Printf("❌ Reply API error: %v", err)
		return fmt.Errorf("failed to send reply: %w", err)
	}

	if !resp.Success() {
		log.Printf("❌ Reply failed: code=%d, msg=%s", resp.Code, resp.Msg)
		// Log more details for debugging
		if resp.Data != nil {
			log.Printf("❌ Response data: %+v", resp.Data)
		}
		return fmt.Errorf("reply failed: code=%d, msg=%s", resp.Code, resp.Msg)
	}

	return nil
}

// handleBotAdded handles the bot being added to a chat
func (g *FeishuGateway) handleBotAdded(ctx context.Context, event *larkim.P1AddBotV1) error {
	if event.Event == nil {
		return nil
	}

	chatID := event.Event.OpenChatID

	log.Printf("🤖 Bot added to chat: %s", chatID)

	// Send a welcome message
	if chatID != "" {
		welcomeMsg := "👋 Hello! I'm ClawPapa, powered by ZeroClaw AI. Send me a message to get started!"
		content := larkim.NewTextMsgBuilder().Text(welcomeMsg).Build()

		_, err := g.apiClient.Im.Message.Create(ctx,
			larkim.NewCreateMessageReqBuilder().
				ReceiveIdType(larkim.ReceiveIdTypeChatId).
				Body(larkim.NewCreateMessageReqBodyBuilder().
					MsgType(larkim.MsgTypeText).
					ReceiveId(chatID).
					Content(content).
					Build()).
				Build())

		if err != nil {
			log.Printf("❌ Failed to send welcome message: %v", err)
		}
	}

	return nil
}

// handleBotRemoved handles the bot being removed from a chat
func (g *FeishuGateway) handleBotRemoved(ctx context.Context, event *larkim.P1RemoveBotV1) error {
	if event.Event == nil {
		return nil
	}

	chatID := event.Event.OpenChatID

	log.Printf("👋 Bot removed from chat: %s", chatID)
	return nil
}

// Start starts the Feishu gateway with WebSocket long connection
func (g *FeishuGateway) Start(ctx context.Context) error {
	// Create event dispatcher
	// Note: Empty strings for verificationToken and eventEncryptKey are correct for WebSocket
	// WebSocket authenticates via AppID/AppSecret in the handshake
	eventHandler := dispatcher.NewEventDispatcher("", "").
		OnP2MessageReceiveV1(g.handleMessage).
		OnP1AddBotV1(g.handleBotAdded).
		OnP1RemoveAddBotV1(g.handleBotRemoved)

	// Create WebSocket client for long connection
	g.wsClient = larkws.NewClient(
		g.config.AppID,
		g.config.AppSecret,
		larkws.WithEventHandler(eventHandler),
		larkws.WithLogLevel(g.config.LogLevel),
		larkws.WithAutoReconnect(true),
	)

	log.Println("🚀 Starting Feishu Gateway with WebSocket Long Connection...")
	log.Printf("📌 App ID: %s", g.config.AppID)
	log.Printf("🦀 ZeroClaw Webhook: %s", g.zeroclawURL)

	// Start WebSocket connection (this blocks)
	err := g.wsClient.Start(ctx)
	if err != nil {
		return fmt.Errorf("failed to start WebSocket client: %w", err)
	}

	return nil
}

// truncate truncates a string to maxLen characters
func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

func main() {
	// Load configuration
	config := LoadConfig()

	if config.AppID == "" || config.AppSecret == "" {
		log.Fatal("❌ FEISHU_APP_ID and FEISHU_APP_SECRET must be set")
	}

	// Create gateway
	gateway := NewFeishuGateway(config)

	// Create context with cancellation for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		sig := <-sigChan
		log.Printf("🛑 Received signal: %v", sig)
		cancel()
	}()

	// Start the gateway
	if err := gateway.Start(ctx); err != nil {
		log.Fatalf("❌ Gateway error: %v", err)
	}
}
