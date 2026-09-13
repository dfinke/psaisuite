package psaisuite

import (
	"context"
	"fmt"
	"os"
	"strings"
)

const defaultModel = "openai:gpt-4o-mini"

func NewChatMessage(prompt, systemRole, systemContent string) []Message {
	messages := make([]Message, 0, 2)
	if systemRole != "" {
		messages = append(messages, Message{Role: systemRole, Content: systemContent})
	}
	messages = append(messages, Message{Role: "user", Content: prompt})
	return messages
}

func InvokeChatCompletion(ctx context.Context, req CompletionRequest, registry ProviderRegistry) (CompletionResponse, error) {
	model := req.Model
	if model == "" {
		model = defaultModel
	}
	if envModel := os.Getenv("PSAISUITE_DEFAULT_MODEL"); envModel != "" {
		model = envModel
	}

	provider, modelName, err := parseModel(model)
	if err != nil {
		return CompletionResponse{}, err
	}

	processed, err := processMessages(req.Messages)
	if err != nil {
		return CompletionResponse{}, err
	}

	if len(req.ContextInputs) > 0 {
		contextString := strings.Join(req.ContextInputs, "\n")
		if req.Messages == nil {
			processed = append(processed, Message{Role: "user", Content: contextString})
		} else {
			processed = append(processed, Message{Role: "user", Content: "Context:\n" + contextString})
		}
	}

	impl, err := registry.Get(provider)
	if err != nil {
		return CompletionResponse{}, err
	}

	text, err := impl.Complete(ctx, ProviderRequest{
		ModelName:      modelName,
		Messages:       processed,
		Tools:          req.Tools,
		ToolExecutions: req.ToolExecutions,
	})
	if err != nil {
		return CompletionResponse{}, err
	}

	return CompletionResponse{
		Messages:  processed,
		Response:  text,
		Model:     model,
		Provider:  provider,
		ModelName: modelName,
	}, nil
}

func parseModel(model string) (string, string, error) {
	parts := strings.SplitN(model, ":", 2)
	if len(parts) != 2 || parts[0] == "" || parts[1] == "" {
		return "", "", fmt.Errorf("model must be specified in 'provider:model' format")
	}
	return strings.ToLower(parts[0]), parts[1], nil
}

func processMessages(input any) ([]Message, error) {
	if input == nil {
		return nil, nil
	}
	switch v := input.(type) {
	case string:
		return []Message{{Role: "user", Content: v}}, nil
	case Message:
		return []Message{v}, nil
	case []Message:
		return v, nil
	case []map[string]string:
		out := make([]Message, 0, len(v))
		for _, m := range v {
			out = append(out, Message{Role: m["role"], Content: m["content"]})
		}
		return out, nil
	default:
		return nil, fmt.Errorf("unsupported messages type %T", input)
	}
}
