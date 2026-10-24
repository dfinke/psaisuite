package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/dfinke/psaisuite/GoPort/psaisuite"
)

func main() {
	prompt := flag.String("prompt", "", "Prompt to send to the model")
	model := flag.String("model", "", "Model in provider:model format (optional)")
	contextInputs := flag.String("context", "", "Context lines separated by '|' (optional)")
	flag.Parse()

	if *prompt == "" {
		fmt.Fprintln(os.Stderr, "error: --prompt is required")
		flag.Usage()
		os.Exit(2)
	}

	registry := buildRegistry()

	req := psaisuite.CompletionRequest{
		Messages: *prompt,
	}
	if *model != "" {
		req.Model = *model
	}
	if *contextInputs != "" {
		req.ContextInputs = strings.Split(*contextInputs, "|")
	}

	resp, err := psaisuite.InvokeChatCompletion(context.Background(), req, registry)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}

	fmt.Println("--- Response ---")
	fmt.Println(resp.Response)
}

// buildRegistry registers all supported providers. Each provider reads its
// required credentials from environment variables at call time, so it is safe
// to include every provider in the registry even when some keys are absent.
func buildRegistry() psaisuite.ProviderRegistry {
	return psaisuite.ProviderRegistry{
		"openai":     psaisuite.NewOpenAIProvider(nil),
		"anthropic":  psaisuite.NewAnthropicProvider(nil),
		"google":     psaisuite.NewGoogleProvider(nil),
		"groq":       psaisuite.NewGroqProvider(nil),
		"mistral":    psaisuite.NewMistralProvider(nil),
		"deepseek":   psaisuite.NewDeepSeekProvider(nil),
		"github":     psaisuite.NewGitHubProvider(nil),
		"perplexity": psaisuite.NewPerplexityProvider(nil),
		"openrouter": psaisuite.NewOpenRouterProvider(nil),
		"nebius":     psaisuite.NewNebiusProvider(nil),
		"inception":  psaisuite.NewInceptionProvider(nil),
		"xai":        psaisuite.NewXAIProvider(nil),
		"azureai":    psaisuite.NewAzureAIProvider(nil),
		"ollama":     psaisuite.NewOllamaProvider(nil),
	}
}
