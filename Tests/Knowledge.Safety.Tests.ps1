Describe 'Agent and knowledge documentation contracts' {
    BeforeAll {
        $repositoryRoot = (Get-Location).Path
        $knowledgeRoot = Join-Path $repositoryRoot '.knowledge'
        $skillsRoot = Join-Path $repositoryRoot '.agents/skills'
        $rulesRoot = Join-Path $repositoryRoot '.agents/rules'

        if (-not (Test-Path -LiteralPath $knowledgeRoot -PathType Container)) {
            throw 'The .knowledge bundle is required.'
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
}
