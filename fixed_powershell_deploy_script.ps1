# --- CONFIGURATION - Adjust these or pass via Harness variables/secrets ---
$appName = "<+pipeline.stages.Build_NetCore.spec.execution.steps.Build.output.outputVariables.PROJECT_DIR_NAME>"
$baseInstallDir = "C:\\Apps"  # Target base directory for installation (escaped for YAML)
$appInstallDir = Join-Path -Path $baseInstallDir -ChildPath $appName

# Artifactory Details - These should be configured securely
$artifactoryBaseUrl = "https://windowsdemo.jfrog.io/artifactory" # Your Artifactory base URL
# $artifactoryRepo = "generic-harness" # This line is not used if $artifactFullRepoPath is the full path from repo root

# Get the artifact filename from CI stage output.
$artifactFileName = "<+pipeline.stages.Build_NetCore.spec.execution.steps.BuildAndZip.output.outputVariables.ARTIFACT_FILE_NAME_ON_AGENT>"

# This expression should resolve to the full path *within* Artifactory.
# e.g., "generic-harness/io/harness/DiegoFrameworkWebApplication/StarWarsCore_win-x64_1.zip"
# This is the 'target' from your ArtifactoryUpload step in CI.
$artifactFullRepoPath = "<+pipeline.stages.Build_NetCore.spec.execution.steps.Upload_to_Artifactory.spec.target>"

# Corrected Line: Added the closing quote for the string interpolation.
$artifactDownloadUrl = "${artifactoryBaseUrl}/${artifactFullRepoPath}"

$artifactoryUser = "diego@sitesantos.com.br" # Consider making this a Harness secret too for consistency
$artifactoryApiKey = "<+secrets.getValue('diego-token-artifactory')>"

$tempDownloadDir = "C:\\temp\\harness_downloads" # Temporary location for the downloaded zip
$localZipFilePath = Join-Path -Path $tempDownloadDir -ChildPath $artifactFileName
# --- END CONFIGURATION ---

# --- DEBUGGING: Print resolved variables ---
Write-Host "DEBUG: appName (resolved by Harness) = '$($appName)'"
Write-Host "DEBUG: baseInstallDir = '$($baseInstallDir)'"
Write-Host "DEBUG: appInstallDir (constructed) = '$($appInstallDir)'"
Write-Host "DEBUG: artifactoryBaseUrl = '$($artifactoryBaseUrl)'"
Write-Host "DEBUG: artifactFileName (resolved from BuildAndZip step) = '$($artifactFileName)'"
Write-Host "DEBUG: artifactFullRepoPath (resolved from Upload_to_Artifactory.spec.target) = '$($artifactFullRepoPath)'"
Write-Host "DEBUG: artifactDownloadUrl (constructed) = '$($artifactDownloadUrl)'"
Write-Host "DEBUG: artifactoryUser = '$($artifactoryUser)'"
# Note: The resolved API key will be masked in Harness logs. This line is for script logic.
Write-Host "DEBUG: artifactoryApiKey (expression) = '<+secrets.getValue('diego-token-artifactory')>'"; # Semicolon added for safety
Write-Host "DEBUG: tempDownloadDir = '$($tempDownloadDir)'"
Write-Host "DEBUG: localZipFilePath (constructed) = '$($localZipFilePath)'"

# Validate essential variables that depend on Harness expressions
if ([string]::IsNullOrWhiteSpace($appName) -or $appName.StartsWith("<+")) {
    Write-Error "CRITICAL VALIDATION FAIL: appName variable did not resolve correctly. Current value: '$($appName)'"
    exit 1
}
if ([string]::IsNullOrWhiteSpace($artifactFileName) -or $artifactFileName.StartsWith("<+")) {
    Write-Error "CRITICAL VALIDATION FAIL: artifactFileName variable did not resolve correctly. Current value: '$($artifactFileName)'"
    exit 1
}
if ([string]::IsNullOrWhiteSpace($artifactFullRepoPath) -or $artifactFullRepoPath.StartsWith("<+")) {
    Write-Error "CRITICAL VALIDATION FAIL: artifactFullRepoPath (from Upload_to_Artifactory.spec.target) did not resolve. Value: '$($artifactFullRepoPath)'"
    exit 1
}
if ([string]::IsNullOrWhiteSpace($artifactDownloadUrl) -or $artifactDownloadUrl -eq ($artifactoryBaseUrl + "/") ) {
    Write-Error "CRITICAL VALIDATION FAIL: artifactDownloadUrl appears incomplete (artifact path might be empty). Value: '$($artifactDownloadUrl)'"
    exit 1
}

$apiKeyIsSecretExpression = $false
if ($artifactoryApiKey -is [string] -and $artifactoryApiKey.StartsWith("<+secrets.getValue")) {
    $apiKeyIsSecretExpression = $true
}

if ($apiKeyIsSecretExpression) {
    Write-Warning "Artifactory API Key secret 'diego-token-artifactory' appears unresolved (still looks like an expression). Check secret name & scope in Harness."
    # Depending on Artifactory setup, may allow anonymous or may fail later.
    # For safety, you might want to set $artifactoryApiKey = $null here if anonymous access is not intended/allowed.
}

# 1. Create temporary download directory if it doesn't exist
if (-not (Test-Path $tempDownloadDir)) {
    Write-Host "Creating temporary download directory: '$tempDownloadDir'"
    New-Item -ItemType Directory -Path $tempDownloadDir -Force
}

# 2. Download the artifact from Artifactory
Write-Host "Downloading artifact from '$artifactDownloadUrl' to '$localZipFilePath'..."
try {
    $headers = @{}
    # Use API Key if it was resolved and is not empty
    if (-not $apiKeyIsSecretExpression -and -not [string]::IsNullOrWhiteSpace($artifactoryApiKey)) {
        $headers["X-JFrog-Art-Api"] = $artifactoryApiKey
        Write-Host "Using X-JFrog-Art-Api header for Artifactory download."
    }
    # Add other auth methods if needed, e.g., Basic Auth with username and resolved API key as password
    # elseif (($artifactoryUser -eq "diego@sitesantos.com.br") -and (-not $apiKeyIsSecretExpression) -and (-not [string]::IsNullOrWhiteSpace($artifactoryApiKey))) {
    #     $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $artifactoryUser, $artifactoryApiKey)))
    #     $headers["Authorization"] = "Basic $base64AuthInfo"
    #     Write-Host "Using Basic Authentication (User + API Key as password) for Artifactory download."
    # }
    else {
        Write-Host "API Key not resolved or not provided; attempting anonymous download (if Artifactory repo allows)."
    }

    Invoke-WebRequest -Uri $artifactDownloadUrl -OutFile $localZipFilePath -Headers $headers -ErrorAction Stop -TimeoutSec 600
    Write-Host "Successfully downloaded artifact."
} catch {
    Write-Error "Failed to download artifact from Artifactory. URL: '$artifactDownloadUrl'. Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Error "Response Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Response.StatusDescription)"
    }
    exit 1
}

if (-not (Test-Path $localZipFilePath)) {
    Write-Error "Downloaded artifact ZIP not found at '$localZipFilePath' after download attempt!"
    exit 1
}

# 3. Ensure target installation directory exists and is clean
if (-not (Test-Path $appInstallDir)) {
    Write-Host "Creating application directory: '$appInstallDir'"
    New-Item -ItemType Directory -Path $appInstallDir -Force
} else {
    $processNameToStop = if ($appName.EndsWith(".exe")) { $appName.Substring(0, $appName.Length - 4) } else { $appName }
    Write-Host "Stopping existing '$processNameToStop' process (if any)..."
    Get-Process -Name $processNameToStop -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    Write-Host "Cleaning existing application directory: '$appInstallDir'"
    Get-ChildItem -Path $appInstallDir | Remove-Item -Recurse -Force
}

# 4. Extract the artifact
Write-Host "Extracting '$localZipFilePath' to '$appInstallDir'..."
try {
    Expand-Archive -Path $localZipFilePath -DestinationPath $appInstallDir -Force -ErrorAction Stop
    Write-Host "Successfully extracted artifact."
} catch {
    Write-Error "Failed to extract artifact: $($_.Exception.Message)"
    exit 1
}

# 5. Start the application
$executableName = if ($appName.EndsWith(".exe")) { $appName } else { "${appName}.exe" }
$exePath = Join-Path -Path $appInstallDir -ChildPath $executableName

if (Test-Path $exePath) {
    Write-Host "Starting application: '$exePath'"
    Start-Process -FilePath $exePath -WorkingDirectory $appInstallDir
    Write-Host "'$appName' started."
} else {
    Write-Error "Application executable not found at '$exePath' after extraction. (Derived from appName: '$appName')"
    exit 1
}

# 6. Clean up downloaded zip file (optional)
Write-Host "Cleaning up downloaded artifact: '$localZipFilePath'"
Remove-Item -Path $localZipFilePath -Force

Write-Host "Deployment script finished successfully."
```
