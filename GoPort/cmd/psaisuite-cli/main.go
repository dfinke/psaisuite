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

	provider := psaisuite.NewOpenAIProvider(nil)
	// Allow overriding API key via env var or programmatically before calling Complete
	provider.APIKey = os.Getenv("OpenAIKey")

	registry := psaisuite.ProviderRegistry{"openai": provider}

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
