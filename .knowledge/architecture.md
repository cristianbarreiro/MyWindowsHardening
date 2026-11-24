---
type: Project Architecture
title: MyWindowsHardening repository architecture
description: Repository layout, supported script families and validation pipeline for Windows hardening work.
status: draft
generated:
  by: openai/gpt-6
  at: 2026-11-24T19:16:00Z
stale_after: 2027-02-22T00:00:00Z
sources:
  - id: root-readme
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/README.md
    title: Repository README
  - id: agent-contract
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/AGENTS.md
    title: Canonical coding-agent contract
  - id: quality-workflow
    resource: https://github.com/cristianbarreiro/MyWindowsHardening/blob/main/.github/workflows/powershell-syntax-validation.yml
    title: GitHub Actions PowerShell quality workflow
---

# Purpose

MyWindowsHardening is a collection of Windows security audit and hardening profiles separated by operating-system family, platform release and security domain. The project deliberately avoids treating Windows 10, Windows 11 and Windows Server as interchangeable targets.[^root-readme]

## Repository areas

| Area | Responsibility | Current boundary |
|---|---|---|
| `Common/` | Cross-client read-only audit tools | Defender audit supports Windows 10/11 client; no configuration changes |
| `Win10/` | Windows 10 baseline and specialized profiles | General baseline is read-only; specialized NTLM/SMB profile has controlled Apply/Restore |
| `Win11/` | Windows 11 baseline and profile designs | General baseline is read-only; specialized Apply/Restore remains pending validation |
| `WinServer/` | Server inventory and role discovery | Initial auditor only; not a universal server configuration baseline |
| `Tests/` | Pester repository-safety tests | Static/safe tests; no live endpoint mutation |
| `.github/workflows/` | PowerShell quality gates | Windows PowerShell 5.1 parser, pinned PSScriptAnalyzer/Pester and Pester test suite |
| `.agents/` | Persistent agent rules and portable skills | Project rules plus on-demand workflows |
| `.knowledge/` | OKF v0.2 context bundle | Source-backed concepts, decisions, freshness and update log |

## CI contract

The current workflow uses `windows-2022`, Windows PowerShell 5.1, Pester 5.6.1 and PSScriptAnalyzer 1.23.0. It parses repository scripts, runs PSScriptAnalyzer with Error severity and executes Pester tests.[^quality-workflow]

A green CI run demonstrates only the checks actually executed. It does not prove a hardening control is effective on every Windows build or that a rollback works on a live device.

## Maintenance boundary

The root [AGENTS.md](../AGENTS.md) is the canonical instruction file. Product-specific agent files are adapters. Keep scripts, profile documentation, tests, source records and OKF concepts synchronized.
