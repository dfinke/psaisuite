package psaisuite

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

// ChatCompletionProvider implements the OpenAI-compatible chat completions API
// (POST /v1/chat/completions, response.choices[0].message.content).
// It is shared by Groq, Mistral, DeepSeek, GitHub, Perplexity, OpenRouter,
// Nebius, Inception, and xAI.
type ChatCompletionProvider struct {
	APIKey     string
	EnvKeyName string
	BaseURL    string
	HTTPClient *http.Client
}

// NewChatCompletionProvider creates a ChatCompletionProvider with the given
// API endpoint URL and the environment-variable name that holds the API key.
func NewChatCompletionProvider(baseURL, envKeyName string, client *http.Client) *ChatCompletionProvider {
	if client == nil {
		client = http.DefaultClient
	}
	return &ChatCompletionProvider{
		BaseURL:    baseURL,
		EnvKeyName: envKeyName,
		HTTPClient: client,
	}
}

func (p *ChatCompletionProvider) Complete(ctx context.Context, req ProviderRequest) (string, error) {
	apiKey := p.APIKey
	if apiKey == "" && p.EnvKeyName != "" {
		apiKey = os.Getenv(p.EnvKeyName)
	}

	body := chatCompletionRequest{
		Model:    req.ModelName,
		Messages: req.Messages,
	}

	data, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.BaseURL, bytes.NewReader(data))
	if err != nil {
		return "", err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	}

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
		return "", fmt.Errorf("api error (HTTP %d)", httpResp.StatusCode)
	}
	if len(out.Choices) == 0 {
		return "", fmt.Errorf("no choices in response")
	}
	return out.Choices[0].Message.Content, nil
}

type chatCompletionRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
}

type chatCompletionResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

// NewGroqProvider creates a provider for the Groq API (env: GROQ_API_KEY).
func NewGroqProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://api.groq.com/openai/v1/chat/completions", "GROQ_API_KEY", client)
}

// NewMistralProvider creates a provider for the Mistral API (env: MistralKey).
func NewMistralProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://api.mistral.ai/v1/chat/completions", "MistralKey", client)
}

// NewDeepSeekProvider creates a provider for the DeepSeek API (env: DeepSeekKey).
func NewDeepSeekProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://api.deepseek.com/v1/chat/completions", "DeepSeekKey", client)
}

// NewGitHubProvider creates a provider for GitHub Models (env: GITHUB_TOKEN).
func NewGitHubProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://models.github.ai/inference/chat/completions", "GITHUB_TOKEN", client)
}

// NewPerplexityProvider creates a provider for the Perplexity API (env: PerplexityKey).
func NewPerplexityProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://api.perplexity.ai/chat/completions", "PerplexityKey", client)
}

// NewOpenRouterProvider creates a provider for the OpenRouter API (env: OpenRouterKey).
func NewOpenRouterProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://openrouter.ai/api/v1/chat/completions", "OpenRouterKey", client)
}

// NewNebiusProvider creates a provider for the Nebius AI API (env: NebiusKey).
func NewNebiusProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://api.studio.nebius.ai/v1/chat/completions", "NebiusKey", client)
}

// NewInceptionProvider creates a provider for the Inception API (env: INCEPTION_API_KEY).
func NewInceptionProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://api.inceptionlabs.ai/v1/chat/completions", "INCEPTION_API_KEY", client)
}

// NewXAIProvider creates a provider for the xAI (Grok) API (env: xAIKey).
func NewXAIProvider(client *http.Client) *ChatCompletionProvider {
	return NewChatCompletionProvider("https://api.x.ai/v1/chat/completions", "xAIKey", client)
}
