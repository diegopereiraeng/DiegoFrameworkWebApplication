# --- CONFIGURATION - Adjust these or pass via Harness variables/secrets ---
$appName = "<+pipeline.stages.Build_NetCore.spec.execution.steps.Build.output.outputVariables.PROJECT_DIR_NAME>"
$baseInstallDir = "C:\\Apps"  # Target base directory for installation (escaped for YAML)
$appInstallDir = Join-Path -Path $baseInstallDir -ChildPath $appName

# Artifactory Details
$artifactoryUser = "harness" # Your Artifactory username for Basic Auth
$artifactoryApiKey = "<+secrets.getValue('harness-jfrog')>" # Your Harness secret for the API key/password

# Clean Base URL for constructing download links
$artifactoryCleanBaseUrl = "https://windowsdemo.jfrog.io/artifactory"

# Get the artifact filename from CI stage output.
# Ensure this expression points to the correct CI step and output variable name.
$artifactFileName = "<+pipeline.stages.Build_NetCore.spec.execution.steps.Build.output.outputVariables.ARTIFACT_ZIP_FILENAME>"

# This is the 'target' from your ArtifactoryUpload step in CI.
# It should be the full path including the repository, e.g., "demo-generic-local/path/to/your/file.zip"
$artifactFullRepoPath = "<+pipeline.stages.Build_NetCore.spec.execution.steps.ArtifactoryUpload.spec.target>"

# Construct a CLEAN download URL - NO embedded credentials
$artifactDownloadUrl = "${artifactoryCleanBaseUrl}/${artifactFullRepoPath}"


$tempDownloadDir = "C:\\temp\\harness_downloads"
# $localZipFilePath will be constructed after validating $artifactFileName
# --- END CONFIGURATION ---

# --- DEBUGGING: Print resolved variables ---
Write-Host "DEBUG: appName (from expression) = '$($appName)'"
Write-Host "DEBUG: artifactFileName (from expression) = '$($artifactFileName)'"
Write-Host "DEBUG: artifactFullRepoPath (from ArtifactoryUpload.spec.target) = '$($artifactFullRepoPath)'"
Write-Host "DEBUG: artifactoryUser (hardcoded for Basic Auth) = '$($artifactoryUser)'"
Write-Host "DEBUG: artifactoryApiKey (expression for secret) = '<+secrets.getValue('harness-jfrog')>'" # Will be masked in logs if resolved
Write-Host "DEBUG: Constructed CLEAN artifactDownloadUrl = '$($artifactDownloadUrl)'"


# CRITICAL VALIDATION for artifactFileName
if ([string]::IsNullOrWhiteSpace($artifactFileName) -or $artifactFileName.StartsWith("<+")) {
    Write-Error "CRITICAL FAIL: artifactFileName variable did not resolve or is empty. Value: '$($artifactFileName)'. Check CI step output variable used in expression."
    exit 1
}
$localZipFilePath = Join-Path -Path $tempDownloadDir -ChildPath $artifactFileName
Write-Host "DEBUG: localZipFilePath (constructed) = '$($localZipFilePath)'"

# Validate other crucial variables
if ([string]::IsNullOrWhiteSpace($appName) -or $appName.StartsWith("<+")) {
    Write-Error "CRITICAL FAIL: appName variable did not resolve or is empty. Value: '$($appName)'."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($artifactFullRepoPath) -or $artifactFullRepoPath.StartsWith("<+")) {
    Write-Error "CRITICAL FAIL: artifactFullRepoPath variable did not resolve or is empty. Value: '$($artifactFullRepoPath)'."
    exit 1
}
if ([string]::IsNullOrWhiteSpace($artifactDownloadUrl) -or $artifactDownloadUrl -eq ($artifactoryCleanBaseUrl + "/")) {
    Write-Error "CRITICAL FAIL: artifactDownloadUrl is incomplete. Value: '$($artifactDownloadUrl)'."
    exit 1
}

# Force modern TLS protocols for Invoke-WebRequest
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls
    Write-Host "DEBUG: Successfully set TLS protocols for ServicePointManager."
} catch {
    Write-Warning "DEBUG: Could not set TLS protocols directly: $($_.Exception.Message). Proceeding, but SSL/TLS errors might occur if defaults are not compatible."
}

if (-not (Test-Path $tempDownloadDir)) {
    Write-Host "Creating temporary download directory: '$tempDownloadDir'"
    New-Item -ItemType Directory -Path $tempDownloadDir -Force
}

Write-Host "Downloading artifact from '$artifactDownloadUrl' to '$localZipFilePath'..."
try {
    $headers = @{}
    $apiKeyIsSecretExpression = $artifactoryApiKey.StartsWith("<+secrets.getValue")

    # Prioritize Basic Authentication if user is specified and API key (as password) is resolved
    if (-not [string]::IsNullOrWhiteSpace($artifactoryUser) -and (-not $apiKeyIsSecretExpression) -and (-not [string]::IsNullOrWhiteSpace($artifactoryApiKey))) {
        $authString = "{0}:{1}" -f $artifactoryUser, $artifactoryApiKey
        $encodedAuthString = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($authString))
        $headers["Authorization"] = "Basic $encodedAuthString"
        Write-Host "Using Basic Authentication (user: '$artifactoryUser') for Artifactory download."
    }
    # Fallback to X-JFrog-Art-Api if only API key is resolved (and no specific user for Basic Auth)
    elseif ((-not $apiKeyIsSecretExpression) -and (-not [string]::IsNullOrWhiteSpace($artifactoryApiKey))) {
        $headers["X-JFrog-Art-Api"] = $artifactoryApiKey
        Write-Host "Using X-JFrog-Art-Api header (API Key only) for Artifactory download (fallback)."
    }
    else {
        Write-Warning "Artifactory credentials (user for Basic Auth and/or API Key secret 'harness-jfrog') not properly resolved or provided. Attempting anonymous download."
    }

    Invoke-WebRequest -Uri $artifactDownloadUrl -OutFile $localZipFilePath -Headers $headers -ErrorAction Stop -TimeoutSec 300
    Write-Host "Successfully downloaded artifact."
} catch {
    Write-Error "Failed to download artifact from Artifactory. URL: '$($artifactDownloadUrl)'. Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Error "Response Status: $($_.Exception.Response.StatusCode) - $($_.Exception.Response.StatusDescription)"
    }
    exit 1
}

if (-not (Test-Path $localZipFilePath)) {
    Write-Error "Downloaded artifact ZIP not found at '$localZipFilePath' after download attempt!"
    exit 1
}

# 3. Ensure target installation directory exists and is clean (same as before)
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

# 4. Extract the artifact (same as before)
Write-Host "Extracting '$localZipFilePath' to '$appInstallDir'..."
try {
    Expand-Archive -Path $localZipFilePath -DestinationPath $appInstallDir -Force -ErrorAction Stop
    Write-Host "Successfully extracted artifact."
} catch {
    Write-Error "Failed to extract artifact: $($_.Exception.Message)"
    exit 1
}

# 5. Start the application (same as before, consider Windows Service for production)
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
