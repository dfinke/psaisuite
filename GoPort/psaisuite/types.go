package psaisuite

import (
	"context"
	"fmt"
)

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type CompletionRequest struct {
	Messages       any
	Model          string
	ContextInputs  []string
	Tools          []ToolDefinition
	ToolExecutions map[string]ToolExecutor
	Raw            bool
}

type CompletionResponse struct {
	Messages  []Message
	Response  string
	Model     string
	Provider  string
	ModelName string
}

type ProviderRequest struct {
	ModelName      string
	Messages       []Message
	Tools          []ToolDefinition
	ToolExecutions map[string]ToolExecutor
}

type Provider interface {
	Complete(ctx context.Context, req ProviderRequest) (string, error)
}

type ToolExecutor func(args map[string]any) (string, error)

type ToolDefinition struct {
	Type     string          `json:"type,omitempty"`
	Name     string          `json:"name"`
	Desc     string          `json:"description,omitempty"`
	Params   map[string]any  `json:"parameters,omitempty"`
	Function *OpenAIFunction `json:"function,omitempty"`
}

type OpenAIFunction struct {
	Name        string         `json:"name"`
	Description string         `json:"description,omitempty"`
	Parameters  map[string]any `json:"parameters,omitempty"`
}

type ProviderRegistry map[string]Provider

func (r ProviderRegistry) Get(name string) (Provider, error) {
	p, ok := r[name]
	if !ok {
		return nil, fmt.Errorf("unsupported provider: %s", name)
	}
	return p, nil
}
