Describe 'Agent and knowledge documentation contracts' {
    BeforeAll {
        $repositoryRoot = (Get-Location).Path
        $knowledgeRoot = Join-Path $repositoryRoot '.knowledge'
        $skillsRoot = Join-Path $repositoryRoot '.agents/skills'
        $rulesRoot = Join-Path $repositoryRoot '.agents/rules'

        if (-not (Test-Path -LiteralPath $knowledgeRoot -PathType Container)) {
            throw 'The .knowledge bundle is required.'
        }
        if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
            throw 'The portable .agents/skills directory is required.'
        }
        if (-not (Test-Path -LiteralPath $rulesRoot -PathType Container)) {
            throw 'The Antigravity .agents/rules directory is required.'
        }

        $conceptFiles = @(
            Get-ChildItem -LiteralPath $knowledgeRoot -Filter '*.md' -Recurse -File |
                Where-Object { $_.Name -notin @('index.md', 'log.md') }
        )
        $skillFiles = @(Get-ChildItem -LiteralPath $skillsRoot -Filter 'SKILL.md' -Recurse -File)
        $ruleFiles = @(Get-ChildItem -LiteralPath $rulesRoot -Filter '*.md' -File)
    }

    It 'the bundle root declares the pinned OKF version' {
        $indexPath = Join-Path $knowledgeRoot 'index.md'
        Test-Path -LiteralPath $indexPath -PathType Leaf | Should -BeTrue
        $indexContent = Get-Content -LiteralPath $indexPath -Raw
        $indexContent | Should -Match '(?s)\A---\r?\nokf_version:\s*["'']?0\.2["'']?\r?\n---'
    }

    It 'every OKF concept has a frontmatter block and non-empty type' {
        $conceptFiles.Count | Should -BeGreaterThan 0

        foreach ($file in $conceptFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $frontmatterMatch = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)')
            $frontmatterMatch.Success | Should -BeTrue
            if ($frontmatterMatch.Success) {
                $frontmatter = $frontmatterMatch.Groups[1].Value
                [regex]::IsMatch($frontmatter, '(?m)^type:\s*\S') | Should -BeTrue
            }
        }
    }

    It 'every portable skill has a matching name and description' {
        $skillFiles.Count | Should -BeGreaterThan 0

        foreach ($file in $skillFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $frontmatterMatch = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)')
            $frontmatterMatch.Success | Should -BeTrue

            if ($frontmatterMatch.Success) {
                $frontmatter = $frontmatterMatch.Groups[1].Value
                $nameMatch = [regex]::Match($frontmatter, '(?m)^name:\s*([a-z0-9-]+)\s*$')
                $descriptionMatch = [regex]::Match($frontmatter, '(?m)^description:\s*\S')
                $nameMatch.Success | Should -BeTrue
                $descriptionMatch.Success | Should -BeTrue

                if ($nameMatch.Success) {
                    $nameMatch.Groups[1].Value | Should -Be $file.Directory.Name
                }
            }
        }
    }

    It 'every Antigravity rule declares a supported trigger' {
        $ruleFiles.Count | Should -BeGreaterThan 0

        foreach ($file in $ruleFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $frontmatterMatch = [regex]::Match($content, '(?s)\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)')
            $frontmatterMatch.Success | Should -BeTrue

            if ($frontmatterMatch.Success) {
                $frontmatter = $frontmatterMatch.Groups[1].Value
                $triggerMatch = [regex]::Match($frontmatter, '(?m)^trigger:\s*(always_on|model_decision|glob|manual)\s*$')
                $triggerMatch.Success | Should -BeTrue
            }
        }
    }

    It 'internal Markdown links in agent and knowledge docs resolve' {
        $documentationFiles = @(
            Get-ChildItem -LiteralPath $knowledgeRoot -Filter '*.md' -Recurse -File
            Get-ChildItem -LiteralPath $skillsRoot -Filter '*.md' -Recurse -File
            Get-ChildItem -LiteralPath $rulesRoot -Filter '*.md' -File
            Get-Item -LiteralPath (Join-Path $repositoryRoot 'AGENTS.md')
            Get-Item -LiteralPath (Join-Path $repositoryRoot 'CLAUDE.md')
            Get-Item -LiteralPath (Join-Path $repositoryRoot 'GEMINI.md')
            Get-Item -LiteralPath (Join-Path $repositoryRoot 'README.md')
            Get-Item -LiteralPath (Join-Path $repositoryRoot 'CONTRIBUTING.md')
            Get-Item -LiteralPath (Join-Path $repositoryRoot 'SECURITY.md')
            Get-Item -LiteralPath (Join-Path $repositoryRoot 'docs/AI-AGENTS.md')
            Get-Item -LiteralPath (Join-Path $repositoryRoot '.github/copilot-instructions.md')
            Get-ChildItem -LiteralPath (Join-Path $repositoryRoot '.github/instructions') -Filter '*.md' -File
        )

        $invalidLinks = New-Object System.Collections.Generic.List[string]
        foreach ($file in $documentationFiles) {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $linkMatches = [regex]::Matches($content, '(?<!!)\[[^\]]+\]\((?<target>[^)]+)\)')

            foreach ($linkMatch in $linkMatches) {
                $target = $linkMatch.Groups['target'].Value.Trim()
                if ($target -match '^(?:[a-z][a-z0-9+.-]*:|#)') {
                    continue
                }

                $target = ($target -split '\s+', 2)[0].Trim('<', '>')
                $target = $target -replace '[#?].*$', ''
                if ([string]::IsNullOrWhiteSpace($target)) {
                    continue
                }

                $candidatePath = if ($target.StartsWith('/')) {
                    Join-Path $repositoryRoot $target.TrimStart('/')
                }
                else {
                    Join-Path (Split-Path -Parent $file.FullName) $target
                }

                if (-not (Test-Path -LiteralPath $candidatePath)) {
                    $invalidLinks.Add(('{0} -> {1}' -f $file.FullName, $target))
                }
            }
        }

        $invalidLinks | Should -BeNullOrEmpty
    }
}
