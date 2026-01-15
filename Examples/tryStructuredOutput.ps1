$rssUrl = "https://finance.yahoo.com/news/rss"
$rssContent = Invoke-WebRequest -Uri $rssUrl -UseBasicParsing

$xml = [xml]$rssContent.Content
# get first news
$items = $xml.rss.channel.item | Select-Object -First 1
# Just to check
$items | ForEach-Object {
    [PSCustomObject]@{
        Title       = $_.title
        Link        = $_.link
        SourceUrl   = $_.source.url
        SourceText  = $_.source.InnerText
        Description = $_.description
        PubDate     = $_.pubDate
    }
} | Format-List


# To parse HTML normally you'd install HtmlAgilityPack package from https://www.nuget.org/packages/HtmlAgilityPack
Add-Type -Path "C:/PSModules/HtmlAgilityPack/lib/net7.0/HtmlAgilityPack.dll"

$headers = @{
    "User-Agent" = "Mozilla/5.0"
}
$html = Invoke-WebRequest -Uri $items.Link -Headers $headers -UseBasicParsing 
$htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
$htmlDoc.LoadHtml($html.Content)
$div = $htmlDoc.DocumentNode.SelectSingleNode("//div[@class='bodyItems-wrapper']")
if ($div) {

    # Clear <section> inside <div>
    $sectionsInsideDiv = $div.SelectNodes(".//section")
    foreach ($section in $sectionsInsideDiv) {
        $section.Remove()
    }

    $cleanText = $div.InnerText.Trim()
    $cleanText | Out-File .\Article.txt
} else {
    Write-Host "Not found!"
}


$ArticleSchema = @{
    type        = "object"
    title       = "High-Yield Savings Account Article Structured Output"
    description = "Structured JSON schema for parsing an article about high-yield savings accounts with APY 4%+."
    required    = @(
        "summary",
        "sentiment",
        "tags",
        "additional_tags",
        "key_points",
        "financial_advice",
        "risks_and_warnings",
        "recommended_actions"
    )
    properties  = @{
        summary = @{
            type        = "string"
            description = "A concise summary of the articles key takeaways (max 3 sentences)."
            example     = "The article compares 10 high-yield savings accounts offering APYs from 4% to 5%, explains how to choose the best option, and provides tips to maximize interest earnings."
        }
        sentiment = @{
            type        = "string"
            enum        = @("positive", "neutral", "negative")
            description = "Tone classification of the article: positive (recommendations, benefits), neutral (objective comparison), or negative (criticism, risks)."
            example     = "positive"
        }
        tags = @{
            type        = "array"
            items       = @{
                type = "string"
            }
            description = "Primary tags for the article."
            example     = @(
                "finance",
                "savings",
                "high-yield",
                "banking",
                "interest_rates"
            )
        }
        additional_tags = @{
            type        = "array"
            items       = @{
                type = "string"
            }
            description = "Additional contextual tags (e.g., specific terms or themes)."
            example     = @(
                "compound_interest",
                "FDIC_insurance",
                "automatic_transfers",
                "Federal_Reserve_policy",
                "CD_alternatives"
            )
        }
        key_points = @{
            type        = "array"
            items       = @{
                type       = "object"
                properties = @{
                    description = @{
                        type        = "string"
                        description = "Brief description of a key idea or fact from the article."
                    }
                }
                required   = @("description")
            }
            description = "List of key takeaways from the article (e.g., account conditions, benefits, risks)."
        }
        financial_advice = @{
            type        = "array"
            items       = @{
                type       = "object"
                properties = @{
                    advice    = @{
                        type        = "string"
                        description = "Actionable financial advice to maximize savings growth."
                    }
                    rationale = @{
                        type        = "string"
                        description = "Explanation of why this advice matters."
                    }
                }
                required   = @("advice", "rationale")
            }
        }
        risks_and_warnings = @{
            type        = "array"
            items       = @{
                type        = "string"
                description = "Potential risks or warnings mentioned in the article (e.g., Federal Reserve rate cuts)."
            }
        }
        recommended_actions = @{
            type        = "array"
            items       = @{
                type        = "string"
                description = "Specific actions readers should take (e.g., 'Compare account terms on the bank's website')."
            }
        }
    }
}

#Change on your path
Import-Module "C:\Git\dfinke\psaisuite\PSAISuite.psm1" -Force

Invoke-ChatCompletion -Messages (cat .\Article.txt)  mistral:ministral-8b-latest -JsonSchema $ArticleSchema 
