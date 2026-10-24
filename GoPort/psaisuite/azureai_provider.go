package psaisuite

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
)

// modelAPIVersion maps specific Azure model names to the API version they
// require. If a model is not listed, defaultAzureAPIVersion is used.
var modelAPIVersion = map[string]string{
	"o3-mini": "2024-12-01-preview",
}

const defaultAzureAPIVersion = "2023-05-15"

func azureAPIVersionFor(modelName string) string {
	if v, ok := modelAPIVersion[modelName]; ok {
		return v
	}
	return defaultAzureAPIVersion
}

// AzureAIProvider calls the Azure AI Foundry (Azure OpenAI) chat completions API.
// Required environment variables: AzureAIKey and AzureAIEndpoint.
type AzureAIProvider struct {
	APIKey     string
	Endpoint   string
	HTTPClient *http.Client
}

// NewAzureAIProvider creates an AzureAIProvider. Pass nil to use the default
// HTTP client.
func NewAzureAIProvider(client *http.Client) *AzureAIProvider {
	if client == nil {
		client = http.DefaultClient
	}
	return &AzureAIProvider{HTTPClient: client}
}

func (p *AzureAIProvider) Complete(ctx context.Context, req ProviderRequest) (string, error) {
	apiKey := p.APIKey
	if apiKey == "" {
		apiKey = os.Getenv("AzureAIKey")
	}
	if apiKey == "" {
		return "", fmt.Errorf("AzureAIKey environment variable is required")
	}

	endpoint := p.Endpoint
	if endpoint == "" {
		endpoint = os.Getenv("AzureAIEndpoint")
	}
	if endpoint == "" {
		return "", fmt.Errorf("AzureAIEndpoint environment variable is required")
	}
	endpoint = strings.TrimRight(endpoint, "/")

	url := fmt.Sprintf("%s/openai/deployments/%s/chat/completions?api-version=%s",
		endpoint, req.ModelName, azureAPIVersionFor(req.ModelName))

	body := chatCompletionRequest{
		Model:    req.ModelName,
		Messages: req.Messages,
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
	httpReq.Header.Set("api-key", apiKey)

	httpResp, err := p.HTTPClient.Do(httpReq)
	if err != nil {
		return "", err
	}
	defer httpResp.Body.Close()

	var out chatCompletionResponse
	if err := json.NewDecoder(httpResp.Body).Decode(&out); err != nil {
		return "", err
	}
	if out.Error.Message != "" {
		return "", fmt.Errorf("%s", out.Error.Message)
	}
	if httpResp.StatusCode >= 400 {
		return "", fmt.Errorf("azure ai api error (HTTP %d)", httpResp.StatusCode)
	}
	if len(out.Choices) == 0 {
		return "", fmt.Errorf("no choices in response")
	}
	return out.Choices[0].Message.Content, nil
}
