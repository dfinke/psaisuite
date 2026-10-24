package psaisuite

import (
	"context"
	"os"
	"net/http"
)

// OllamaProvider is a chat completions provider for a local Ollama instance.
// The base URL is resolved at call time from the OLLAMA_HOST environment
// variable (default: http://localhost:11434). The API key (env: OllamaKey)
// is optional – many local Ollama deployments require no authentication.
type OllamaProvider struct {
	APIKey     string
	Host       string
	HTTPClient *http.Client
}

// NewOllamaProvider creates an OllamaProvider. Pass nil to use the default
// HTTP client.
func NewOllamaProvider(client *http.Client) *OllamaProvider {
	if client == nil {
		client = http.DefaultClient
	}
	return &OllamaProvider{HTTPClient: client}
}

func (p *OllamaProvider) Complete(ctx context.Context, req ProviderRequest) (string, error) {
	host := p.Host
	if host == "" {
		host = os.Getenv("OLLAMA_HOST")
	}
	if host == "" {
		host = "http://localhost:11434"
	}

	inner := &ChatCompletionProvider{
		APIKey:     p.APIKey,
		EnvKeyName: "OllamaKey",
		BaseURL:    host + "/v1/chat/completions",
		HTTPClient: p.HTTPClient,
	}
	return inner.Complete(ctx, req)
}
