package psaisuite

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

const anthropicMessagesURL = "https://api.anthropic.com/v1/messages"
const anthropicVersion = "2023-06-01"

// AnthropicProvider calls the Anthropic Messages API.
// API key is read from the AnthropicKey environment variable.
type AnthropicProvider struct {
	APIKey     string
	BaseURL    string
	HTTPClient *http.Client
}

// NewAnthropicProvider creates an AnthropicProvider. Pass nil to use the
// default HTTP client.
func NewAnthropicProvider(client *http.Client) *AnthropicProvider {
	if client == nil {
		client = http.DefaultClient
	}
	return &AnthropicProvider{HTTPClient: client}
}

func (p *AnthropicProvider) Complete(ctx context.Context, req ProviderRequest) (string, error) {
	apiKey := p.APIKey
	if apiKey == "" {
		apiKey = os.Getenv("AnthropicKey")
	}
	if apiKey == "" {
		return "", fmt.Errorf("AnthropicKey environment variable is required")
	}

	baseURL := p.BaseURL
	if baseURL == "" {
		baseURL = anthropicMessagesURL
	}

	// Separate system message from the rest.
	var systemContent string
	messages := make([]Message, 0, len(req.Messages))
	for _, m := range req.Messages {
		if m.Role == "system" {
			systemContent = m.Content
		} else {
			messages = append(messages, m)
		}
	}

	body := anthropicRequest{
		Model:     req.ModelName,
		MaxTokens: 1024,
		Messages:  messages,
	}
	if systemContent != "" {
		body.System = systemContent
	}

	data, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL, bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	httpReq.Header.Set("x-api-key", apiKey)
	httpReq.Header.Set("anthropic-version", anthropicVersion)
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := p.HTTPClient.Do(httpReq)
	if err != nil {
		return "", err
	}
	defer httpResp.Body.Close()

	var out anthropicResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&out); err != nil {
		return "", err
	}
	if out.Error.Message != "" {
		return "", fmt.Errorf("anthropic api error: %s", out.Error.Message)
	}
	if httpResp.StatusCode >= 400 {
		return "", fmt.Errorf("anthropic api error (HTTP %d)", httpResp.StatusCode)
	}

	for _, block := range out.Content {
		if block.Type == "text" {
			return block.Text, nil
		}
	}
	return "", fmt.Errorf("no text content in anthropic response")
}

type anthropicRequest struct {
	Model     string    `json:"model"`
	MaxTokens int       `json:"max_tokens"`
	Messages  []Message `json:"messages"`
	System    string    `json:"system,omitempty"`
}

type anthropicResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}
