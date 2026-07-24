[CmdletBinding()]
param(
    [string]$BaselineTag = "upstream-baseline-package-conversion-20260724"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot ".git"))) {
    throw "Repository root could not be resolved from $PSScriptRoot"
}

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-DriftError([string]$Message) {
    $script:errors.Add($Message)
}

function Add-DriftWarning([string]$Message) {
    $script:warnings.Add($Message)
}

$requiredFiles = @(
    "Package.swift",
    "Sources/SwiftChatCore/Models/AttachmentModels.swift",
    "Sources/SwiftChatCore/Models/ChatModels.swift",
    "Sources/SwiftChatCore/Services/StreamingMarkdownChunker.swift",
    "Sources/SwiftChatCore/Services/ThinkingTextChunker.swift",
    "Sources/SwiftChatUI/ViewModels/ChatViewModel.swift",
    "Sources/SwiftChatUI/Views/ChatView.swift",
    "Sources/SwiftChatOpenAI/AppConfig.swift",
    "Sources/SwiftChatOpenAI/ChatQueryBuilder.swift",
    "Sources/SwiftChatOpenAI/OpenAIResponsesProvider.swift",
    "Sources/SwiftChat/Exports.swift"
)

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relativePath))) {
        Add-DriftError "Required canonical file is missing: $relativePath"
    }
}

$retiredSharedPaths = @(
    "SwiftChat/Models",
    "SwiftChat/ViewModels",
    "SwiftChat/Views",
    "SwiftChat/Services",
    "SwiftChat/Utilities",
    "SwiftChat/Config",
    "SwiftChat/Extensions"
)

foreach ($relativePath in $retiredSharedPaths) {
    $retiredPath = Join-Path $repoRoot $relativePath
    $retiredFiles = if (Test-Path -LiteralPath $retiredPath) {
        Get-ChildItem -LiteralPath $retiredPath -Recurse -File
    }
    if ($retiredFiles) {
        Add-DriftError "Old shared path was recreated and may duplicate package code: $relativePath"
    }
}

$swiftFiles = Get-ChildItem -Path (Join-Path $repoRoot "Sources") -Recurse -File -Filter "*.swift"
$duplicateSwiftNames = $swiftFiles |
    Group-Object -Property Name |
    Where-Object Count -gt 1

foreach ($duplicate in $duplicateSwiftNames) {
    $paths = ($duplicate.Group | ForEach-Object {
        $_.FullName.Substring($repoRoot.Length + 1)
    }) -join ", "
    Add-DriftError "Duplicate package Swift filename '$($duplicate.Name)': $paths"
}

$appSwiftFiles = Get-ChildItem -Path (Join-Path $repoRoot "SwiftChat") -Recurse -File -Filter "*.swift"
$allowedAppSources = @("ContentView.swift", "SwiftChatApp.swift")
foreach ($file in $appSwiftFiles) {
    if ($file.Name -notin $allowedAppSources) {
        Add-DriftError "Shared implementation appears in the app target: $($file.FullName.Substring($repoRoot.Length + 1))"
    }
}

$projectText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "SwiftChat.xcodeproj/project.pbxproj")
if ($projectText -notmatch "XCLocalSwiftPackageReference") {
    Add-DriftError "Xcode project does not reference the local root package."
}
foreach ($product in @("SwiftChatCore", "SwiftChatUI", "SwiftChatOpenAI")) {
    if ($projectText -notmatch [regex]::Escape("productName = $product;")) {
        Add-DriftError "SwiftChat app target does not depend on the $product package product."
    }
}
if ($projectText -match "XCRemoteSwiftPackageReference `"openai-swift-fork`"") {
    Add-DriftError "The app project owns OpenAI directly instead of consuming the local package."
}

$manifestText = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "Package.swift")
foreach ($product in @("SwiftChatCore", "SwiftChatUI", "SwiftChatOpenAI", "SwiftChat")) {
    if ($manifestText -notmatch [regex]::Escape(".library(name: `"$product`"")) {
        Add-DriftError "Package product is missing: $product"
    }
}

$resourceRoots = @(
    (Join-Path $repoRoot "SwiftChat"),
    (Join-Path $repoRoot "Sources/SwiftChatUI/Resources")
)
$resourceFiles = foreach ($resourceRoot in $resourceRoots) {
    if (Test-Path -LiteralPath $resourceRoot) {
        Get-ChildItem -Path $resourceRoot -Recurse -File |
            Where-Object Extension -In @(".png", ".jpg", ".jpeg", ".svg", ".json")
    }
}

$duplicateResourceHashes = $resourceFiles |
    ForEach-Object {
        [pscustomobject]@{
            Path = $_.FullName
            Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
        }
    } |
    Group-Object -Property Hash |
    Where-Object Count -gt 1

foreach ($duplicate in $duplicateResourceHashes) {
    $paths = ($duplicate.Group | ForEach-Object {
        $_.Path.Substring($repoRoot.Length + 1)
    }) -join ", "
    Add-DriftWarning "Byte-identical resources found: $paths"
}

git -C $repoRoot rev-parse --verify "$BaselineTag^{commit}" *> $null
if ($LASTEXITCODE -ne 0) {
    Add-DriftError "Baseline tag is missing: $BaselineTag"
} else {
    $baselineSources = git -C $repoRoot ls-tree -r --name-only $BaselineTag -- "SwiftChat"
    if (-not $baselineSources) {
        Add-DriftWarning "No baseline Swift sources were returned; verify the baseline tag."
    }
}

foreach ($warning in $warnings) {
    Write-Warning $warning
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Error $message -ErrorAction Continue
    }
    throw "Upstream drift check failed with $($errors.Count) error(s)."
}

Write-Host "Upstream drift check passed."
Write-Host "Canonical package Swift files: $($swiftFiles.Count)"
Write-Host "App-only Swift files: $($appSwiftFiles.Count)"
