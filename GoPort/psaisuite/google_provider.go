package psaisuite

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

const googleBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"

// GoogleProvider calls the Google Gemini generateContent API.
// API key is read from the GeminiKey environment variable.
type GoogleProvider struct {
	APIKey     string
	BaseURL    string
	HTTPClient *http.Client
}

// NewGoogleProvider creates a GoogleProvider. Pass nil to use the default
// HTTP client.
func NewGoogleProvider(client *http.Client) *GoogleProvider {
	if client == nil {
		client = http.DefaultClient
	}
	return &GoogleProvider{HTTPClient: client}
}

func (p *GoogleProvider) Complete(ctx context.Context, req ProviderRequest) (string, error) {
	apiKey := p.APIKey
	if apiKey == "" {
		apiKey = os.Getenv("GeminiKey")
	}
	if apiKey == "" {
		return "", fmt.Errorf("GeminiKey environment variable is required")
	}

	baseURL := p.BaseURL
	if baseURL == "" {
		baseURL = googleBaseURL
	}

	url := fmt.Sprintf("%s/%s:generateContent?key=%s", baseURL, req.ModelName, apiKey)

	// Convert messages: "system" role becomes system_instruction; "user" role
	// becomes a content entry; "assistant" role maps to "model".
	var systemText string
	contents := make([]googleContent, 0, len(req.Messages))
	for _, m := range req.Messages {
		switch m.Role {
		case "system":
			systemText = m.Content
		case "assistant":
			contents = append(contents, googleContent{
				Role:  "model",
				Parts: []googlePart{{Text: m.Content}},
			})
		default:
			contents = append(contents, googleContent{
				Role:  m.Role,
				Parts: []googlePart{{Text: m.Content}},
			})
		}
	}

	body := googleRequest{Contents: contents}
	if systemText != "" {
		body.SystemInstruction = &googleSystemInstruction{
			Parts: []googlePart{{Text: systemText}},
		}
	}

	data, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	httpResp, err := p.HTTPClient.Do(httpReq)
	if err != nil {
		return "", err
	}
	defer httpResp.Body.Close()

	var out googleResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&out); err != nil {
		return "", err
	}
	if out.Error.Message != "" {
		return "", fmt.Errorf("google api error: %s", out.Error.Message)
	}
	if httpResp.StatusCode >= 400 {
		return "", fmt.Errorf("google api error (HTTP %d)", httpResp.StatusCode)
	}
	if len(out.Candidates) == 0 {
		return "", fmt.Errorf("no candidates in google response")
	}

	for _, part := range out.Candidates[0].Content.Parts {
		if part.Text != "" {
			return part.Text, nil
		}
	}
	return "", fmt.Errorf("no text content in google response")
}

type googleRequest struct {
	Contents          []googleContent           `json:"contents"`
	SystemInstruction *googleSystemInstruction  `json:"system_instruction,omitempty"`
}

type googleSystemInstruction struct {
	Parts []googlePart `json:"parts"`
}

type googleContent struct {
	Role  string       `json:"role"`
	Parts []googlePart `json:"parts"`
}

type googlePart struct {
	Text string `json:"text"`
}

type googleResponse struct {
	Candidates []struct {
		Content struct {
			Parts []googlePart `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}
