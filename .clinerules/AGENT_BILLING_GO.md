# Agent-First Resource Accounting & Billing System Design

> **Implementation Mandate**: All ZeroClaw workers and services MUST be implemented in Go. This is a hard requirement for consistency, performance, and maintainability across the entire billing infrastructure.

## Table of Contents

1. [Overview](#overview)
2. [Protocol Selection](#protocol-selection)
3. [Architecture](#architecture)
4. [Go Implementation Guide](#go-implementation-guide)
5. [NATS Integration](#nats-integration)
6. [tikoWallet Integration](#tikowallet-integration)
7. [Security Model](#security-model)
8. [Implementation Roadmap](#implementation-roadmap)

---

## Overview

### Purpose

Design a succinct, simple, and effective agent-first resource accounting, billing, and settlement/payment system for ZeroClaw services. The system enables AI agents to autonomously track resource usage, bill for services, and settle payments without human intervention.

### Key Principles

1. **Agent-First**: Agents are self-sovereign with autonomous financial operations
2. **Event-Driven**: Asynchronous architecture using NATS JetStream
3. **Go-Native**: All workers and services implemented in Go
4. **Minimal API Surface**: Simple, clear interfaces with 4 core operations
5. **Trustless**: Cryptographic signatures for all financial transactions

### Technology Stack

| Component | Technology | Go Package |
|-----------|------------|------------|
| **Messaging** | NATS JetStream | `github.com/nats-io/nats.go` |
| **Serialization** | JSON | `encoding/json` |
| **Cryptography** | Ed25519 | `crypto/ed25519` |
| **Logging** | Structured | `log/slog` (Go 1.21+) |
| **Wallet** | tikoWallet | Custom client |

---

## Protocol Selection

### Recommended: A2A + x402 over NATS

#### Why This Combination?

| Protocol | Use Case | Rationale |
|----------|----------|-----------|
| **A2A** | Agent-to-agent communication | Designed for autonomous agent interactions, service discovery, and negotiation |
| **x402** | Payment flows | Lightweight payment protocol inspired by HTTP 402 Payment Required |
| **NATS** | Transport layer | Battle-tested messaging with JetStream persistence, pub/sub, and request/reply |

#### Why NOT MCP for Billing?

- **MCP (Model Context Protocol)** is designed for model context management, not financial operations
- MCP adds unnecessary complexity for simple billing operations
- A2A + x402 provides a more direct, efficient path for agent financial autonomy

### Protocol Layering

```
┌─────────────────────────────────────┐
│   Application Layer (Agents)        │
├─────────────────────────────────────┤
│   A2A (Agent-to-Agent Protocol)     │  ← Service Discovery & Negotiation
├─────────────────────────────────────┤
│   x402 (Payment Protocol)           │  ← Billing & Settlement
├─────────────────────────────────────┤
│   NATS JetStream (Transport)        │  ← Messaging & Persistence
└─────────────────────────────────────┘
```

---

## Architecture

### System Components

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Agent A    │────▶│    NATS      │◀────│   Agent B    │
│  (Consumer)  │     │  JetStream   │     │  (Provider)  │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                     │
       │ A2A/x402           │ Events              │ A2A/x402
       │                    │                     │
       ▼                    ▼                     ▼
┌──────────────────────────────────────────────────────┐
│         Resource Accounting Service (Go)             │
│  - Tracks usage events                               │
│  - Calculates costs                                  │
│  - Generates invoices                                │
└────────────────────┬─────────────────────────────────┘
                     │
                     │ x402 Settlement
                     │
                     ▼
            ┌─────────────────┐
            │   tikoWallet    │
            │  (Settlement)   │
            └─────────────────┘
```

### Data Flow

1. **Service Delivery**: Agent B provides service to Agent A
2. **Usage Reporting**: Agent B reports resource usage to NATS
3. **Accounting**: Resource Accounting Service aggregates usage
4. **Billing**: Invoice generated and sent to Agent A
5. **Authorization**: Agent A authorizes payment
6. **Settlement**: tikoWallet executes the transfer

---

## Go Implementation Guide

### Core Data Structures

```go
// AgentID represents a unique agent identifier
type AgentID string

// ResourceUsage represents a resource usage event
type ResourceUsage struct {
    Protocol    string            `json:"protocol"`     // "a2a"
    Version     string            `json:"version"`      // "1.0"
    Type        string            `json:"type"`         // "ResourceUsage"
    Timestamp   time.Time         `json:"timestamp"`
    AgentID     AgentID           `json:"agent_id"`
    SessionID   string            `json:"session_id"`
    ConsumerID  AgentID           `json:"consumer_agent_id"`
    Resources   map[string]float64 `json:"resources"`
    Metadata    map[string]string `json:"metadata,omitempty"`
}

// Invoice represents a billing invoice
type Invoice struct {
    Protocol    string      `json:"protocol"`     // "x402"
    Version     string      `json:"version"`      // "1.0"
    Type        string      `json:"type"`         // "Invoice"
    InvoiceID   string      `json:"invoice_id"`
    Timestamp   time.Time   `json:"timestamp"`
    FromAgent   AgentID     `json:"from_agent_id"`
    ToAgent     AgentID     `json:"to_agent_id"`
    Period      Period      `json:"period"`
    LineItems   []LineItem  `json:"line_items"`
    Total       float64     `json:"total"`
    Currency    string      `json:"currency"`
    PaymentDue  time.Time   `json:"payment_due"`
    WalletAddr  string      `json:"wallet_address"`
}

// LineItem represents a single billing line item
type LineItem struct {
    Description string  `json:"description"`
    Quantity    float64 `json:"quantity"`
    Unit        string  `json:"unit"`
    Rate        float64 `json:"rate"`
    Amount      float64 `json:"amount"`
}

// Period represents a billing period
type Period struct {
    Start time.Time `json:"start"`
    End   time.Time `json:"end"`
}

// PaymentAuth represents a payment authorization
type PaymentAuth struct {
    Protocol    string    `json:"protocol"`     // "a2a"
    Version     string    `json:"version"`      // "1.0"
    Type        string    `json:"type"`         // "PaymentAuthorization"
    Timestamp   time.Time `json:"timestamp"`
    FromAgent   AgentID   `json:"from_agent_id"`
    ToAgent     AgentID   `json:"to_agent_id"`
    InvoiceID   string    `json:"invoice_id"`
    Auth        Auth      `json:"authorization"`
    ExpiresAt   time.Time `json:"expires_at"`
}

// Auth contains authorization details
type Auth struct {
    Amount      float64 `json:"amount"`
    Currency    string  `json:"currency"`
    Source      string  `json:"wallet_source"`
    Destination string  `json:"wallet_dest"`
    Signature   string  `json:"signature"`
    Nonce       string  `json:"nonce"`
}

// SettlementReceipt represents a settlement confirmation
type SettlementReceipt struct {
    Protocol      string    `json:"protocol"`      // "x402"
    Version       string    `json:"version"`       // "1.0"
    Type          string    `json:"type"`          // "SettlementReceipt"
    Timestamp     time.Time `json:"timestamp"`
    TransactionID string    `json:"transaction_id"`
    InvoiceID     string    `json:"invoice_id"`
    FromAgent     AgentID   `json:"from_agent_id"`
    ToAgent       AgentID   `json:"to_agent_id"`
    Amount        float64   `json:"amount"`
    Currency      string    `json:"currency"`
    Status        string    `json:"status"`       // "completed", "failed"
    BlockchainTx  string    `json:"blockchain_tx,omitempty"`
    ReceiptSig    string    `json:"receipt_signature"`
}

// AgentIdentity represents an agent's identity and wallet
type AgentIdentity struct {
    AgentID      AgentID            `json:"agent_id"`
    Wallet       AgentWallet        `json:"wallet"`
    Capabilities []ServiceCapability `json:"capabilities"`
    Rates        map[string]float64 `json:"rates"`  // Service pricing
}

// AgentWallet represents an agent's wallet information
type AgentWallet struct {
    WalletAddress string    `json:"wallet_address"`  // tiko:agent_xxx
    PublicKey     string    `json:"public_key"`      // Ed25519
    Balance       float64   `json:"balance"`
    CreditLimit   float64   `json:"credit_limit"`
}

// ServiceCapability represents a service an agent can provide
type ServiceCapability struct {
    Service     string  `json:"service"`
    Description string  `json:"description"`
    Rate        float64 `json:"rate"`
    Unit        string  `json:"unit"`
}
```

---

## NATS Integration

### Connection Setup

```go
package billing

import (
    "context"
    "fmt"
    "log/slog"
    "time"

    "github.com/nats-io/nats.go"
)

// NATSClient manages NATS connection and operations
type NATSClient struct {
    nc     *nats.Conn
    js     nats.JetStreamContext
    logger *slog.Logger
}

// NewNATSClient creates a new NATS client
func NewNATSClient(ctx context.Context, urls string, opts ...nats.Option) (*NATSClient, error) {
    // Default options
    defaultOpts := []nats.Option{
        nats.Name("zeroclaw-billing-worker"),
        nats.ReconnectWait(2 * time.Second),
        nats.MaxReconnects(10),
        nats.DisconnectErrHandler(func(nc *nats.Conn, err error) {
            slog.Error("Disconnected from NATS", "error", err)
        }),
        nats.ReconnectHandler(func(nc *nats.Conn) {
            slog.Info("Reconnected to NATS", "url", nc.ConnectedUrl())
        }),
        nats.ClosedHandler(func(nc *nats.Conn) {
            slog.Error("NATS connection closed", "error", nc.LastError())
        }),
    }
    
    opts = append(defaultOpts, opts...)
    
    nc, err := nats.Connect(urls, opts...)
    if err != nil {
        return nil, fmt.Errorf("failed to connect to NATS: %w", err)
    }
    
    // Create JetStream context
    js, err := nc.JetStream()
    if err != nil {
        nc.Close()
        return nil, fmt.Errorf("failed to create JetStream context: %w", err)
    }
    
    return &NATSClient{
        nc:     nc,
        js:     js,
        logger: slog.Default(),
    }, nil
}

// Close closes the NATS connection
func (c *NATSClient) Close() {
    if c.nc != nil {
        c.nc.Close()
    }
}

// SetupStreams creates required JetStream streams
func (c *NATSClient) SetupStreams(ctx context.Context) error {
    // Resource usage stream
    _, err := c.js.AddStream(&nats.StreamConfig{
        Name:     "RESOURCE_USAGE",
        Subjects: []string{"resource.usage.>"},
        Retention: nats.LimitsPolicy,
        MaxMsgs:  1000000,
        MaxBytes: 1024 * 1024 * 1024, // 1GB
        MaxAge:   30 * 24 * time.Hour, // 30 days
        Storage:  nats.FileStorage,
    }, nats.Context(ctx))
    if err != nil {
        return fmt.Errorf("failed to create RESOURCE_USAGE stream: %w", err)
    }
    
    // Billing stream
    _, err = c.js.AddStream(&nats.StreamConfig{
        Name:     "BILLING",
        Subjects: []string{"billing.>"},
        Retention: nats.LimitsPolicy,
        MaxMsgs:  100000,
        MaxBytes: 512 * 1024 * 1024, // 512MB
        MaxAge:   365 * 24 * time.Hour, // 1 year
        Storage:  nats.FileStorage,
    }, nats.Context(ctx))
    if err != nil {
        return fmt.Errorf("failed to create BILLING stream: %w", err)
    }
    
    // Payment stream
    _, err = c.js.AddStream(&nats.StreamConfig{
        Name:     "PAYMENT",
        Subjects: []string{"payment.>"},
        Retention: nats.LimitsPolicy,
        MaxMsgs:  100000,
        MaxBytes: 256 * 1024 * 1024, // 256MB
        MaxAge:   365 * 24 * time.Hour, // 1 year
        Storage:  nats.FileStorage,
    }, nats.Context(ctx))
    if err != nil {
        return fmt.Errorf("failed to create PAYMENT stream: %w", err)
    }
    
    // Settlement stream
    _, err = c.js.AddStream(&nats.StreamConfig{
        Name:     "SETTLEMENT",
        Subjects: []string{"settlement.>"},
        Retention: nats.LimitsPolicy,
        MaxMsgs:  100000,
        MaxBytes: 256 * 1024 * 1024, // 256MB
        MaxAge:   365 * 24 * time.Hour, // 1 year
        Storage:  nats.FileStorage,
    }, nats.Context(ctx))
    if err != nil {
        return fmt.Errorf("failed to create SETTLEMENT stream: %w", err)
    }
    
    c.logger.Info("JetStream streams created successfully")
    return nil
}
```

### NATS Subject Patterns

```go
// NATS subject patterns for the billing system
const (
    // Resource usage events
    SubjectResourceUsage = "resource.usage.%s.%s"  // resource.usage.{service_type}.{provider_agent_id}
    
    // Billing events
    SubjectInvoice       = "billing.invoice.%s"    // billing.invoice.{consumer_agent_id}
    SubjectStatement     = "billing.statement.%s"  // billing.statement.{consumer_agent_id}
    
    // Payment events
    SubjectPaymentAuth   = "payment.auth.%s"       // payment.auth.{provider_agent_id}
    SubjectPaymentComplete = "payment.completed.%s" // payment.completed.{consumer_agent_id}
    
    // Settlement events
    SubjectSettlementComplete = "settlement.completed.%s" // settlement.completed.{agent_id}
    SubjectSettlementFailed   = "settlement.failed.%s"    // settlement.failed.{agent_id}
    
    // Agent discovery (A2A)
    SubjectAgentDiscover = "agent.discover.%s"     // agent.discover.{service_type}
    SubjectAgentAvailable = "agent.available.%s"   // agent.available.{agent_id}
)
```

---

## Agent SDK (Go Implementation)

### SDK Interface

```go
package sdk

import (
    "context"
    "time"
)

// AgentBillingSDK provides the main interface for agents
type AgentBillingSDK interface {
    // ReportUsage reports resource usage (async event)
    ReportUsage(ctx context.Context, usage *ResourceUsage) error
    
    // SubscribeInvoices subscribes to invoices for this agent
    SubscribeInvoices(ctx context.Context) (<-chan *Invoice, error)
    
    // AuthorizePayment authorizes a payment
    AuthorizePayment(ctx context.Context, invoice *Invoice) (*PaymentAuth, error)
    
    // SubscribeSettlements subscribes to settlement notifications
    SubscribeSettlements(ctx context.Context) (<-chan *SettlementReceipt, error)
    
    // Close closes the SDK connection
    Close() error
}

// BillingConfig contains SDK configuration
type BillingConfig struct {
    NATSURLs       string
    AgentID        AgentID
    PrivateKey     string  // Ed25519 private key (hex)
    WalletAddress  string  // tiko:agent_xxx
    Logger         *slog.Logger
}

// billingSDK implements the AgentBillingSDK interface
type billingSDK struct {
    client    *NATSClient
    config    *BillingConfig
    privateKey ed25519.PrivateKey
    logger    *slog.Logger
}
```

### SDK Implementation

```go
package sdk

import (
    "context"
    "crypto/ed25519"
    "encoding/hex"
    "encoding/json"
    "fmt"
    "log/slog"
    "time"

    "github.com/nats-io/nats.go"
)

// NewAgentBillingSDK creates a new agent billing SDK
func NewAgentBillingSDK(ctx context.Context, config *BillingConfig) (AgentBillingSDK, error) {
    // Parse private key
    privKeyBytes, err := hex.DecodeString(config.PrivateKey)
    if err != nil {
        return nil, fmt.Errorf("failed to decode private key: %w", err)
    }
    
    if len(privKeyBytes) != ed25519.PrivateKeySize {
        return nil, fmt.Errorf("invalid private key size: expected %d, got %d",
            ed25519.PrivateKeySize, len(privKeyBytes))
    }
    
    // Create NATS client
    client, err := NewNATSClient(ctx, config.NATSURLs,
        nats.Name(fmt.Sprintf("agent-%s", config.AgentID)),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to create NATS client: %w", err)
    }
    
    logger := config.Logger
    if logger == nil {
        logger = slog.Default()
    }
    
    return &billingSDK{
        client:     client,
        config:     config,
        privateKey: ed25519.PrivateKey(privKeyBytes),
        logger:     logger,
    }, nil
}

// ReportUsage reports resource usage
func (s *billingSDK) ReportUsage(ctx context.Context, usage *ResourceUsage) error {
    // Set protocol metadata
    usage.Protocol = "a2a"
    usage.Version = "1.0"
    usage.Type = "ResourceUsage"
    usage.Timestamp = time.Now()
    usage.AgentID = s.config.AgentID
    
    // Marshal to JSON
    data, err := json.Marshal(usage)
    if err != nil {
        return fmt.Errorf("failed to marshal resource usage: %w", err)
    }
    
    // Publish to NATS
    subject := fmt.Sprintf(SubjectResourceUsage, 
        usage.Metadata["service_type"], usage.AgentID)
    
    _, err = s.client.js.Publish(subject, data, nats.Context(ctx))
    if err != nil {
        return fmt.Errorf("failed to publish resource usage: %w", err)
    }
    
    s.logger.Debug("Reported resource usage",
        "session_id", usage.SessionID,
        "consumer", usage.ConsumerID,
        "subject", subject,
    )
    
    return nil
}

// SubscribeInvoices subscribes to invoices
func (s *billingSDK) SubscribeInvoices(ctx context.Context) (<-chan *Invoice, error) {
    invoiceCh := make(chan *Invoice, 100)
    
    subject := fmt.Sprintf(SubjectInvoice, s.config.AgentID)
    
    sub, err := s.client.js.Subscribe(subject, func(msg *nats.Msg) {
        var invoice Invoice
        if err := json.Unmarshal(msg.Data, &invoice); err != nil {
            s.logger.Error("Failed to unmarshal invoice", "error", err)
            msg.Nak()
            return
        }
        
        select {
        case invoiceCh <- &invoice:
            msg.Ack()
        case <-ctx.Done():
            msg.Nak()
            return
        }
    }, nats.DeliverAll(), nats.ManualAck())
    
    if err != nil {
        close(invoiceCh)
        return nil, fmt.Errorf("failed to subscribe to invoices: %w", err)
    }
    
    // Handle context cancellation
    go func() {
        <-ctx.Done()
        sub.Unsubscribe()
        close(invoiceCh)
    }()
    
    return invoiceCh, nil
}

// AuthorizePayment authorizes a payment
func (s *billingSDK) AuthorizePayment(ctx context.Context, invoice *Invoice) (*PaymentAuth, error) {
    // Create authorization
    auth := &PaymentAuth{
        Protocol:  "a2a",
        Version:   "1.0",
        Type:      "PaymentAuthorization",
        Timestamp: time.Now(),
        FromAgent: s.config.AgentID,
        ToAgent:   invoice.FromAgent,
        InvoiceID: invoice.InvoiceID,
        Auth: Auth{
            Amount:      invoice.Total,
            Currency:    invoice.Currency,
            Source:      s.config.WalletAddress,
            Destination: invoice.WalletAddr,
            Nonce:       generateNonce(),
        },
        ExpiresAt: time.Now().Add(1 * time.Hour),
    }
    
    // Sign the authorization
    message := fmt.Sprintf("%s:%s:%.8f:%s",
        auth.InvoiceID, auth.Auth.Nonce, auth.Auth.Amount, auth.Auth.Currency)
    signature := ed25519.Sign(s.privateKey, []byte(message))
    auth.Auth.Signature = hex.EncodeToString(signature)
    
    // Marshal to JSON
    data, err := json.Marshal(auth)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal payment authorization: %w", err)
    }
    
    // Publish to NATS
    subject := fmt.Sprintf(SubjectPaymentAuth, invoice.FromAgent)
    _, err = s.client.js.Publish(subject, data, nats.Context(ctx))
    if err != nil {
        return nil, fmt.Errorf("failed to publish payment authorization: %w", err)
    }
    
    s.logger.Info("Authorized payment",
        "invoice_id", invoice.InvoiceID,
        "amount", invoice.Total,
        "currency", invoice.Currency,
    )
    
    return auth, nil
}

// SubscribeSettlements subscribes to settlement notifications
func (s *billingSDK) SubscribeSettlements(ctx context.Context) (<-chan *SettlementReceipt, error) {
    settlementCh := make(chan *SettlementReceipt, 100)
    
    subject := fmt.Sprintf(SubjectSettlementComplete, s.config.AgentID)
    
    sub, err := s.client.js.Subscribe(subject, func(msg *nats.Msg) {
        var receipt SettlementReceipt
        if err := json.Unmarshal(msg.Data, &receipt); err != nil {
            s.logger.Error("Failed to unmarshal settlement receipt", "error", err)
            msg.Nak()
            return
        }
        
        select {
        case settlementCh <- &receipt:
            msg.Ack()
        case <-ctx.Done():
            msg.Nak()
            return
        }
    }, nats.DeliverAll(), nats.ManualAck())
    
    if err != nil {
        close(settlementCh)
        return nil, fmt.Errorf("failed to subscribe to settlements: %w", err)
    }
    
    // Handle context cancellation
    go func() {
        <-ctx.Done()
        sub.Unsubscribe()
        close(settlementCh)
    }()
    
    return settlementCh, nil
}

// Close closes the SDK
func (s *billingSDK) Close() error {
    s.client.Close()
    return nil
}

// Helper function to generate nonce
func generateNonce() string {
    b := make([]byte, 16)
    rand.Read(b)
    return hex.EncodeToString(b)
}
```

---

## Resource Accounting Service (Go Implementation)

```go
package accounting

import (
    "context"
    "encoding/json"
    "fmt"
    "log/slog"
    "sync"
    "time"

    "github.com/nats-io/nats.go"
)

// AccountingService tracks resource usage and generates invoices
type AccountingService struct {
    client      *NATSClient
    usageStore  UsageStore
    pricing     PricingEngine
    logger      *slog.Logger
    mu          sync.RWMutex
}

// UsageStore persists resource usage data
type UsageStore interface {
    Store(ctx context.Context, usage *ResourceUsage) error
    GetUsage(ctx context.Context, agentID AgentID, period Period) ([]*ResourceUsage, error)
    Close() error
}

// PricingEngine calculates costs
type PricingEngine interface {
    CalculateCost(usage *ResourceUsage) (float64, error)
    GetRate(serviceType, unit string) (float64, error)
}

// NewAccountingService creates a new accounting service
func NewAccountingService(ctx context.Context, client *NATSClient, store UsageStore, pricing PricingEngine) (*AccountingService, error) {
    svc := &AccountingService{
        client:     client,
        usageStore: store,
        pricing:    pricing,
        logger:     slog.Default(),
    }
    
    // Subscribe to resource usage events
    if err := svc.subscribeUsage(ctx); err != nil {
        return nil, fmt.Errorf("failed to subscribe to usage events: %w", err)
    }
    
    return svc, nil
}

// subscribeUsage subscribes to resource usage events
func (s *AccountingService) subscribeUsage(ctx context.Context) error {
    sub, err := s.client.js.Subscribe("resource.usage.>", func(msg *nats.Msg) {
        var usage ResourceUsage
        if err := json.Unmarshal(msg.Data, &usage); err != nil {
            s.logger.Error("Failed to unmarshal resource usage", "error", err)
            msg.Nak()
            return
        }
        
        // Store usage
        if err := s.usageStore.Store(ctx, &usage); err != nil {
            s.logger.Error("Failed to store resource usage", "error", err)
            msg.Nak()
            return
        }
        
        s.logger.Debug("Stored resource usage",
            "agent", usage.AgentID,
            "consumer", usage.ConsumerID,
            "session", usage.SessionID,
        )
        
        msg.Ack()
    }, nats.DeliverAll(), nats.ManualAck(), nats.Durable("accounting-service"))
    
    if err != nil {
        return fmt.Errorf("failed to subscribe to resource usage: %w", err)
    }
    
    return nil
}

// GenerateInvoice generates an invoice for a billing period
func (s *AccountingService) GenerateInvoice(ctx context.Context, providerID, consumerID AgentID, period Period) (*Invoice, error) {
    // Get usage data for the period
    usage, err := s.usageStore.GetUsage(ctx, providerID, period)
    if err != nil {
        return nil, fmt.Errorf("failed to get usage data: %w", err)
    }
    
    // Filter by consumer
    var consumerUsage []*ResourceUsage
    for _, u := range usage {
        if u.ConsumerID == consumerID {
            consumerUsage = append(consumerUsage, u)
        }
    }
    
    if len(consumerUsage) == 0 {
        return nil, fmt.Errorf("no usage found for consumer %s in period", consumerID)
    }
    
    // Aggregate usage and calculate costs
    lineItems := s.aggregateUsage(consumerUsage)
    
    // Calculate total
    var total float64
    for _, item := range lineItems {
        total += item.Amount
    }
    
    // Create invoice
    invoice := &Invoice{
        Protocol:   "x402",
        Version:    "1.0",
        Type:       "Invoice",
        InvoiceID:  fmt.Sprintf("inv_%d_%s", time.Now().Unix(), consumerID),
        Timestamp:  time.Now(),
        FromAgent:  providerID,
        ToAgent:    consumerID,
        Period:     period,
        LineItems:  lineItems,
        Total:      total,
        Currency:   "USD",
        PaymentDue: time.Now().Add(24 * time.Hour),
        WalletAddr: fmt.Sprintf("tiko:%s", providerID),
    }
    
    return invoice, nil
}

// aggregateUsage aggregates usage data into line items
func (s *AccountingService) aggregateUsage(usage []*ResourceUsage) []LineItem {
    aggregated := make(map[string]*LineItem)
    
    for _, u := range usage {
        serviceType := u.Metadata["service_type"]
        
        for resource, quantity := range u.Resources {
            key := fmt.Sprintf("%s:%s", serviceType, resource)
            
            rate, err := s.pricing.GetRate(serviceType, resource)
            if err != nil {
                s.logger.Warn("Failed to get rate", 
                    "service", serviceType, 
                    "resource", resource, 
                    "error", err,
                )
                continue
            }
            
            if item, exists := aggregated[key]; exists {
                item.Quantity += quantity
                item.Amount += quantity * rate
            } else {
                aggregated[key] = &LineItem{
                    Description: fmt.Sprintf("%s (%s)", serviceType, resource),
                    Quantity:    quantity,
                    Unit:        resource,
                    Rate:        rate,
                    Amount:      quantity * rate,
                }
            }
        }
    }
    
    items := make([]LineItem, 0, len(aggregated))
    for _, item := range aggregated {
        items = append(items, *item)
    }
    
    return items
}

// PublishInvoice publishes an invoice to the billing stream
func (s *AccountingService) PublishInvoice(ctx context.Context, invoice *Invoice) error {
    data, err := json.Marshal(invoice)
    if err != nil {
        return fmt.Errorf("failed to marshal invoice: %w", err)
    }
    
    subject := fmt.Sprintf(SubjectInvoice, invoice.ToAgent)
    _, err = s.client.js.Publish(subject, data, nats.Context(ctx))
    if err != nil {
        return fmt.Errorf("failed to publish invoice: %w", err)
    }
    
    s.logger.Info("Published invoice",
        "invoice_id", invoice.InvoiceID,
        "from", invoice.FromAgent,
        "to", invoice.ToAgent,
        "total", invoice.Total,
    )
    
    return nil
}
```

---

## tikoWallet Integration

### tikoWallet Client

```go
package tikowallet

import (
    "context"
    "crypto/ed25519"
    "encoding/hex"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "time"
)

// TikoWalletClient provides integration with tikoWallet service
type TikoWalletClient struct {
    baseURL    string
    httpClient *http.Client
    logger     *slog.Logger
}

// TikoWalletConfig contains configuration for tikoWallet client
type TikoWalletConfig struct {
    BaseURL string
    Timeout time.Duration
    Logger  *slog.Logger
}

// NewTikoWalletClient creates a new tikoWallet client
func NewTikoWalletClient(config *TikoWalletConfig) *TikoWalletClient {
    timeout := config.Timeout
    if timeout == 0 {
        timeout = 30 * time.Second
    }
    
    logger := config.Logger
    if logger == nil {
        logger = slog.Default()
    }
    
    return &TikoWalletClient{
        baseURL: config.BaseURL,
        httpClient: &http.Client{
            Timeout: timeout,
        },
        logger: logger,
    }
}

// TransferRequest represents a transfer request
type TransferRequest struct {
    FromAgent  AgentID `json:"from_agent_id"`
    ToAgent    AgentID `json:"to_agent_id"`
    Amount     float64 `json:"amount"`
    Currency   string  `json:"currency"`
    Signature  string  `json:"signature"`
    InvoiceID  string  `json:"invoice_id,omitempty"`
}

// TransferResponse represents a transfer response
type TransferResponse struct {
    TransactionID string    `json:"transaction_id"`
    Status        string    `json:"status"`
    Timestamp     time.Time `json:"timestamp"`
    BlockchainTx  string    `json:"blockchain_tx,omitempty"`
}

// BalanceResponse represents a balance query response
type BalanceResponse struct {
    AgentID      AgentID `json:"agent_id"`
    Balance      float64 `json:"balance"`
    CreditLimit  float64 `json:"credit_limit"`
    Currency     string  `json:"currency"`
}

// GetBalance gets an agent's wallet balance
func (c *TikoWalletClient) GetBalance(ctx context.Context, agentID AgentID) (*BalanceResponse, error) {
    url := fmt.Sprintf("%s/api/v1/agents/%s/balance", c.baseURL, agentID)
    
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }
    
    resp, err := c.httpClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("failed to get balance: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return nil, fmt.Errorf("failed to get balance: status %d, body: %s", resp.StatusCode, string(body))
    }
    
    var balance BalanceResponse
    if err := json.NewDecoder(resp.Body).Decode(&balance); err != nil {
        return nil, fmt.Errorf("failed to decode balance response: %w", err)
    }
    
    return &balance, nil
}

// Transfer transfers funds between agents
func (c *TikoWalletClient) Transfer(ctx context.Context, req *TransferRequest) (*TransferResponse, error) {
    url := fmt.Sprintf("%s/api/v1/transfers", c.baseURL)
    
    body, err := json.Marshal(req)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal transfer request: %w", err)
    }
    
    httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }
    
    httpReq.Header.Set("Content-Type", "application/json")
    
    resp, err := c.httpClient.Do(httpReq)
    if err != nil {
        return nil, fmt.Errorf("failed to transfer: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
        respBody, _ := io.ReadAll(resp.Body)
        return nil, fmt.Errorf("failed to transfer: status %d, body: %s", resp.StatusCode, string(respBody))
    }
    
    var transfer TransferResponse
    if err := json.NewDecoder(resp.Body).Decode(&transfer); err != nil {
        return nil, fmt.Errorf("failed to decode transfer response: %w", err)
    }
    
    return &transfer, nil
}

// VerifySignature verifies a payment authorization signature
func (c *TikoWalletClient) VerifySignature(ctx context.Context, agentID AgentID, message, signature string) (bool, error) {
    // Get agent's public key
    url := fmt.Sprintf("%s/api/v1/agents/%s/public-key", c.baseURL, agentID)
    
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return false, fmt.Errorf("failed to create request: %w", err)
    }
    
    resp, err := c.httpClient.Do(req)
    if err != nil {
        return false, fmt.Errorf("failed to get public key: %w", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return false, fmt.Errorf("failed to get public key: status %d, body: %s", resp.StatusCode, string(body))
    }
    
    var result struct {
        PublicKey string `json:"public_key"`
    }
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return false, fmt.Errorf("failed to decode public key response: %w", err)
    }
    
    // Decode public key
    pubKeyBytes, err := hex.DecodeString(result.PublicKey)
    if err != nil {
        return false, fmt.Errorf("failed to decode public key: %w", err)
    }
    
    // Decode signature
    sigBytes, err := hex.DecodeString(signature)
    if err != nil {
        return false, fmt.Errorf("failed to decode signature: %w", err)
    }
    
    // Verify signature
    return ed25519.Verify(pubKeyBytes, []byte(message), sigBytes), nil
}
```

---

## Security Model

### Agent Identity & Authentication

```go
package security

import (
    "crypto/ed25519"
    "crypto/rand"
    "encoding/hex"
    "fmt"
)

// AgentCredentials represents an agent's cryptographic credentials
type AgentCredentials struct {
    AgentID    AgentID
    PublicKey  string // Hex-encoded Ed25519 public key
    PrivateKey string // Hex-encoded Ed25519 private key
}

// GenerateAgentCredentials generates new agent credentials
func GenerateAgentCredentials(agentID AgentID) (*AgentCredentials, error) {
    publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
    if err != nil {
        return nil, fmt.Errorf("failed to generate key pair: %w", err)
    }
    
    return &AgentCredentials{
        AgentID:    agentID,
        PublicKey:  hex.EncodeToString(publicKey),
        PrivateKey: hex.EncodeToString(privateKey),
    }, nil
}

// SignMessage signs a message using the agent's private key
func SignMessage(privateKeyHex string, message string) (string, error) {
    privKeyBytes, err := hex.DecodeString(privateKeyHex)
    if err != nil {
        return "", fmt.Errorf("failed to decode private key: %w", err)
    }
    
    signature := ed25519.Sign(privKeyBytes, []byte(message))
    return hex.EncodeToString(signature), nil
}

// VerifySignature verifies a message signature
func VerifySignature(publicKeyHex string, message string, signatureHex string) (bool, error) {
    pubKeyBytes, err := hex.DecodeString(publicKeyHex)
    if err != nil {
        return false, fmt.Errorf("failed to decode public key: %w", err)
    }
    
    sigBytes, err := hex.DecodeString(signatureHex)
    if err != nil {
        return false, fmt.Errorf("failed to decode signature: %w", err)
    }
    
    return ed25519.Verify(pubKeyBytes, []byte(message), sigBytes), nil
}
```

### Authorization Verification

```go
package security

import (
    "fmt"
    "time"
)

// PaymentVerifier verifies payment authorizations
type PaymentVerifier struct {
    walletClient *tikowallet.TikoWalletClient
}

// NewPaymentVerifier creates a new payment verifier
func NewPaymentVerifier(walletClient *tikowallet.TikoWalletClient) *PaymentVerifier {
    return &PaymentVerifier{
        walletClient: walletClient,
    }
}

// VerifyAuthorization verifies a payment authorization
func (v *PaymentVerifier) VerifyAuthorization(auth *PaymentAuth) error {
    // Check expiration
    if time.Now().After(auth.ExpiresAt) {
        return fmt.Errorf("authorization has expired")
    }
    
    // Verify signature
    message := fmt.Sprintf("%s:%s:%.8f:%s",
        auth.InvoiceID,
        auth.Auth.Nonce,
        auth.Auth.Amount,
        auth.Auth.Currency,
    )
    
    valid, err := v.walletClient.VerifySignature(
        context.Background(),
        auth.FromAgent,
        message,
        auth.Auth.Signature,
    )
    if err != nil {
        return fmt.Errorf("failed to verify signature: %w", err)
    }
    
    if !valid {
        return fmt.Errorf("invalid signature")
    }
    
    // Check balance
    balance, err := v.walletClient.GetBalance(context.Background(), auth.FromAgent)
    if err != nil {
        return fmt.Errorf("failed to get balance: %w", err)
    }
    
    available := balance.Balance + balance.CreditLimit
    if available < auth.Auth.Amount {
        return fmt.Errorf("insufficient funds: available %.2f, required %.2f",
            available, auth.Auth.Amount)
    }
    
    return nil
}
```

---

## Implementation Roadmap

### Phase 1: Core Infrastructure (Week 1-2)

**Objectives**:
- Deploy NATS with JetStream
- Implement agent identity system
- Create basic resource usage tracking
- Set up tikoWallet integration

**Deliverables**:
- [ ] NATS deployment with JetStream enabled
- [ ] Go package for NATS client (`internal/natsclient`)
- [ ] Agent credential generation utility (`cmd/gen-agent-creds`)
- [ ] Basic usage tracking service (`cmd/usage-tracker`)
- [ ] tikoWallet Go client (`pkg/tikowallet`)

**Dependencies**:
```go
// go.mod
module github.com/chancejiang/zeroclaw/billing

go 1.22

require (
    github.com/nats-io/nats.go v1.49.0
)
```

### Phase 2: Billing Engine (Week 3-4)

**Objectives**:
- Build accounting service
- Implement invoice generation
- Create payment authorization flow
- Add settlement notification

**Deliverables**:
- [ ] Accounting service (`cmd/accounting-service`)
- [ ] Invoice generation logic
- [ ] Payment authorization endpoint
- [ ] Settlement notification handler
- [ ] Usage store implementation (SQLite/PostgreSQL)

**Configuration**:
```yaml
# config/accounting.yaml
nats:
  urls: "nats://localhost:4222"
  
storage:
  type: "sqlite"
  path: "/var/lib/zeroclaw/billing.db"
  
pricing:
  default_currency: "USD"
  services:
    llm_inference:
      tokens:
        rate: 0.0001
      compute_units:
        rate: 0.001
```

### Phase 3: Agent SDK (Week 5-6)

**Objectives**:
- Go SDK for ZeroClaw agents
- Integration with existing ZeroClaw workers
- Comprehensive documentation
- Integration tests

**Deliverables**:
- [ ] Agent SDK package (`pkg/agent-sdk`)
- [ ] Example worker implementation (`examples/billing-worker`)
- [ ] Integration test suite (`tests/integration`)
- [ ] Documentation (`docs/agent-sdk.md`)

### Phase 4: Advanced Features (Week 7-8)

**Objectives**:
- Service discovery (A2A)
- Budget management
- Multi-currency support
- Analytics dashboard

**Deliverables**:
- [ ] Service discovery service (`cmd/discovery-service`)
- [ ] Budget management API
- [ ] Currency conversion service
- [ ] Analytics dashboard (Yew frontend)

---

## Go Best Practices

### 1. Context Usage

Always use `context.Context` for cancellation and timeout:

```go
// Good
func (s *Service) Process(ctx context.Context, data *Data) error {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
        // Process data
    }
}

// Bad
func (s *Service) Process(data *Data) error {
    // No way to cancel
}
```

### 2. Error Handling

Use wrapped errors with context:

```go
// Good
if err != nil {
    return fmt.Errorf("failed to process invoice %s: %w", invoiceID, err)
}

// Bad
if err != nil {
    return err
}
```

### 3. Structured Logging

Use `log/slog` for structured logging:

```go
// Good
logger.Info("Processing payment",
    "invoice_id", invoice.InvoiceID,
    "amount", invoice.Total,
    "currency", invoice.Currency,
)

// Bad
log.Printf("Processing payment for invoice %s: amount=%f", invoice.InvoiceID, invoice.Total)
```

### 4. Interface Design

Define interfaces at the consumer, not the producer:

```go
// Good (consumer defines interface)
type InvoiceProcessor interface {
    Process(ctx context.Context, invoice *Invoice) error
}

func NewService(processor InvoiceProcessor) *Service {
    return &Service{processor: processor}
}

// Bad (producer defines interface)
type AccountingService interface {
    ProcessInvoice(ctx context.Context, invoice *Invoice) error
    // ... many other methods
}
```

### 5. Goroutine Management

Always manage goroutine lifecycle:

```go
// Good
func (s *Service) Start(ctx context.Context) error {
    errCh := make(chan error, 1)
    
    go func() {
        if err := s.run(ctx); err != nil {
            select {
            case errCh <- err:
            default:
            }
        }
    }()
    
    select {
    case err := <-errCh:
        return err
    case <-ctx.Done():
        return ctx.Err()
    }
}
```

---

## Configuration Management

### Environment Variables

```go
package config

import (
    "os"
    "strconv"
    "time"
)

// Config holds all configuration
type Config struct {
    NATS      NATSConfig
    Storage   StorageConfig
    TikoWallet TikoWalletConfig
    Pricing   PricingConfig
}

// NATSConfig holds NATS configuration
type NATSConfig struct {
    URLs         string
    MaxReconnect int
    ReconnectWait time.Duration
}

// LoadConfig loads configuration from environment
func LoadConfig() *Config {
    return &Config{
        NATS: NATSConfig{
            URLs:         getEnv("NATS_URLS", "nats://localhost:4222"),
            MaxReconnect: getEnvInt("NATS_MAX_RECONNECT", 10),
            ReconnectWait: getEnvDuration("NATS_RECONNECT_WAIT", 2*time.Second),
        },
        Storage: StorageConfig{
            Type: getEnv("STORAGE_TYPE", "sqlite"),
            Path: getEnv("STORAGE_PATH", "/var/lib/zeroclaw/billing.db"),
        },
        TikoWallet: TikoWalletConfig{
            BaseURL: getEnv("TIKOWALLET_URL", "http://localhost:8080"),
            Timeout: getEnvDuration("TIKOWALLET_TIMEOUT", 30*time.Second),
        },
    }
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if i, err := strconv.Atoi(value); err == nil {
            return i
        }
    }
    return defaultValue
}

func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
    if value := os.Getenv(key); value != "" {
        if d, err := time.ParseDuration(value); err == nil {
            return d
        }
    }
    return defaultValue
}
```

---

## Monitoring & Observability

### Metrics

```go
package metrics

import (
    "context"
    "expvar"
    "runtime"
    "time"
)

// Metrics holds service metrics
type Metrics struct {
    UsageEventsProcessed  *expvar.Int
    InvoicesGenerated     *expvar.Int
    PaymentsAuthorized    *expvar.Int
    SettlementsCompleted  *expvar.Int
    ProcessingDuration    *expvar.Map
}

// NewMetrics creates a new metrics instance
func NewMetrics() *Metrics {
    return &Metrics{
        UsageEventsProcessed:  expvar.NewInt("usage_events_processed"),
        InvoicesGenerated:     expvar.NewInt("invoices_generated"),
        PaymentsAuthorized:    expvar.NewInt("payments_authorized"),
        SettlementsCompleted:  expvar.NewInt("settlements_completed"),
        ProcessingDuration:    expvar.NewMap("processing_duration_ms"),
    }
}

// RecordDuration records processing duration
func (m *Metrics) RecordDuration(operation string, start time.Time) {
    duration := time.Since(start).Milliseconds()
    m.ProcessingDuration.Add(operation, duration)
}
```

### Health Checks

```go
package health

import (
    "context"
    "encoding/json"
    "net/http"
    "time"
)

// HealthChecker provides health check endpoints
type HealthChecker struct {
    natsClient  *NATSClient
    db         UsageStore
    wallet     *tikowallet.TikoWalletClient
}

// HealthResponse represents health check response
type HealthResponse struct {
    Status    string            `json:"status"`
    Timestamp time.Time         `json:"timestamp"`
    Checks    map[string]Check  `json:"checks"`
}

// Check represents a single health check
type Check struct {
    Status  string `json:"status"`
    Latency int64  `json:"latency_ms"`
}

// ServeHTTP implements http.Handler
func (h *HealthChecker) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    
    response := HealthResponse{
        Status:    "healthy",
        Timestamp: time.Now(),
        Checks:    make(map[string]Check),
    }
    
    // Check NATS
    start := time.Now()
    if h.natsClient.nc.IsConnected() {
        response.Checks["nats"] = Check{
            Status:  "healthy",
            Latency: time.Since(start).Milliseconds(),
        }
    } else {
        response.Checks["nats"] = Check{
            Status:  "unhealthy",
            Latency: time.Since(start).Milliseconds(),
        }
        response.Status = "unhealthy"
    }
    
    // Check database
    start = time.Now()
    if err := h.db.Ping(ctx); err == nil {
        response.Checks["database"] = Check{
            Status:  "healthy",
            Latency: time.Since(start).Milliseconds(),
        }
    } else {
        response.Checks["database"] = Check{
            Status:  "unhealthy",
            Latency: time.Since(start).Milliseconds(),
        }
        response.Status = "unhealthy"
    }
    
    // Check tikoWallet
    start = time.Now()
    if _, err := h.wallet.GetBalance(ctx, "test-agent"); err == nil || err.Error() == "not found" {
        response.Checks["tikowallet"] = Check{
            Status:  "healthy",
            Latency: time.Since(start).Milliseconds(),
        }
    } else {
        response.Checks["tikowallet"] = Check{
            Status:  "unhealthy",
            Latency: time.Since(start).Milliseconds(),
        }
    }
    
    // Write response
    w.Header().Set("Content-Type", "application/json")
    if response.Status == "unhealthy" {
        w.WriteHeader(http.StatusServiceUnavailable)
    }
    json.NewEncoder(w).Encode(response)
}
```

---

## Summary

This design provides:

1. **Agent-First Architecture**: Agents are autonomous and self-sovereign
2. **Succinct API**: 4 core operations (ReportUsage, SubscribeInvoices, AuthorizePayment, SubscribeSettlements)
3. **Simple Design**: Clear separation of concerns between resource tracking, billing, and settlement
4. **Effective Protocol**: A2A for agent interactions, x402 for payments, NATS for transport
5. **Go-Native**: All code examples and implementations use Go idioms and best practices
6. **Production-Ready**: Includes error handling, logging, metrics, and health checks

### Key Files to Create

```
zeroclaw/billing/
├── cmd/
│   ├── accounting-service/
│   │   └── main.go
│   ├── usage-tracker/
│   │   └── main.go
│   └── gen-agent-creds/
│       └── main.go
├── pkg/
│   ├── agent-sdk/
│   │   ├── sdk.go
│   │   └── types.go
│   ├── tikowallet/
│   │   └── client.go
│   └── security/
│       └── credentials.go
├── internal/
│   ├── natsclient/
│   │   └── client.go
│   ├── accounting/
│   │   └── service.go
│   └── storage/
│       └── sqlite.go
├── config/
│   └── accounting.yaml
└── go.mod
```

### Quick Start

```bash
# Initialize Go module
go mod init github.com/chancejiang/zeroclaw/billing

# Add dependencies
go get github.com/nats-io/nats.go@latest

# Generate agent credentials
go run cmd/gen-agent-creds/main.go --agent-id "agent_zeroclaw_001"

# Start accounting service
go run cmd/accounting-service/main.go

# Start usage tracker
go run cmd/usage-tracker/main.go
```

This design is ready for implementation and provides a solid foundation for your agent-first billing system. All workers are implemented in Go as mandated, with proper error handling, context usage, and Go idioms throughout.