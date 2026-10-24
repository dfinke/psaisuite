package psaisuite

import (
	"context"
	"os"
	"testing"
)

type stubProvider struct {
	response string
	req      ProviderRequest
}

func (s *stubProvider) Complete(_ context.Context, req ProviderRequest) (string, error) {
	s.req = req
	return s.response, nil
}

func TestInvokeChatCompletionAddsContextWhenMessagesProvided(t *testing.T) {
	provider := &stubProvider{response: "ok"}
	resp, err := InvokeChatCompletion(context.Background(), CompletionRequest{
		Messages:      "prompt",
		Model:         "openai:gpt-4o-mini",
		ContextInputs: []string{"line1", "line2"},
	}, ProviderRegistry{"openai": provider})
	if err != nil {
		t.Fatalf("InvokeChatCompletion() error = %v", err)
	}
	if got := provider.req.Messages[len(provider.req.Messages)-1].Content; got != "Context:\nline1\nline2" {
		t.Fatalf("expected context message, got %q", got)
	}
	if resp.Provider != "openai" || resp.ModelName != "gpt-4o-mini" {
		t.Fatalf("unexpected response metadata: %+v", resp)
	}
}

func TestInvokeChatCompletionUsesEnvDefaultModel(t *testing.T) {
	t.Setenv("PSAISUITE_DEFAULT_MODEL", "openai:gpt-4.1-mini")
	provider := &stubProvider{response: "ok"}
	resp, err := InvokeChatCompletion(context.Background(), CompletionRequest{Messages: "prompt"}, ProviderRegistry{"openai": provider})
	if err != nil {
		t.Fatalf("InvokeChatCompletion() error = %v", err)
	}
	if resp.Model != "openai:gpt-4.1-mini" {
		t.Fatalf("expected env model, got %q", resp.Model)
	}
}

func TestParseModelFormatValidation(t *testing.T) {
	if _, _, err := parseModel("invalid"); err == nil {
		t.Fatal("expected format error")
	}
}

func TestNewChatMessage(t *testing.T) {
	messages := NewChatMessage("hello", "system", "you are helpful")
	if len(messages) != 2 {
		t.Fatalf("expected 2 messages, got %d", len(messages))
	}
	if messages[0].Role != "system" || messages[1].Role != "user" {
		t.Fatalf("unexpected roles: %+v", messages)
	}
}

func TestMain(m *testing.M) {
	_ = os.Unsetenv("PSAISUITE_DEFAULT_MODEL")
	os.Exit(m.Run())
}
