# StarWarsCore ASP.NET Core Application

This application displays a Star Wars opening crawl animation. It has been converted from an older ASP.NET Framework application to a modern ASP.NET Core 8 application.

## Running the Application

This application is configured to serve static HTML, CSS, and JavaScript.

### Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (for building or running with `dotnet run`)
- OR a Windows VM where a self-contained deployment can be run.

### Option 1: Running with `dotnet run` (Requires .NET 8 SDK)

1.  Navigate to the `StarWarsCore` directory in your terminal.
2.  Run the command: `dotnet run`
3.  The application will typically be available at `http://localhost:5000` or `https://localhost:5001`. Check the terminal output for the exact URLs.

### Option 2: Publishing a Self-Contained Deployment for Windows

This option creates an executable that includes the .NET runtime, so the .NET SDK does not need to be installed on the target Windows VM.

1.  **Publish the application:**
    Open a terminal in the `StarWarsCore` project directory and run the following command:
    ```bash
    dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true
    ```
    *   `-c Release`: Builds the application in Release configuration.
    *   `-r win-x64`: Targets the Windows 64-bit platform.
    *   `--self-contained true`: Includes the .NET runtime with the application.
    *   `/p:PublishSingleFile=true`: (Optional but recommended for simplicity) Packages the application and its dependencies into a single executable file.

2.  **Locate the published files:**
    The output will be in `StarWarsCore/bin/Release/net8.0/win-x64/publish/`.
    If you used `/p:PublishSingleFile=true`, you will find `StarWarsCore.exe` here. Otherwise, you'll see `StarWarsCore.exe` along with several other DLLs and files.

3.  **Deploy to Windows VM:**
    Copy the entire `publish` directory (or just `StarWarsCore.exe` if `PublishSingleFile` was true) to your Windows VM.

4.  **Run on Windows VM:**
    Double-click `StarWarsCore.exe` on the Windows VM. A terminal window will open, and the application will start. It will typically listen on `http://localhost:5000`. You can then open a web browser on the VM to this address to see the application.

    *Note on Ports:* If port 5000 is in use, ASP.NET Core will try to use another port. The actual port will be shown in the terminal window when the application starts. You might also need to configure Windows Firewall to allow incoming connections to the port if you want to access it from other machines. For local access on the VM itself, this is usually not necessary.

### Content
The main page is `wwwroot/index.html`.

---

## CI/CD with Harness (Example)

This section provides an example of how to build this application in a CI/CD pipeline using Harness, assuming a Linux-based CI environment and deployment to a Windows VM.

### 1. Building the Application in Harness CI (Linux Environment)

The application can be built using Docker within your Harness CI pipeline. This project includes a `Dockerfile` optimized for building the self-contained Windows executable.

**Dockerfile (`StarWarsCore/Dockerfile`):**
```dockerfile
# Use the .NET 8 SDK image for building
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env

WORKDIR /app

# Copy the .csproj file and restore dependencies first to leverage Docker layer caching
COPY *.csproj ./
RUN dotnet restore

# Copy the rest of the application files
COPY . ./

# Publish the application for Windows x64 self-contained
# Output will be in /app/publish
RUN dotnet publish -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true -o /app/publish
```

**Harness CI Pipeline Step (Example):**

You can use a "Build and Push Docker Image" step if you want to store the image, or more commonly for this scenario, a `Run` script step to build the image and extract the artifact.

Here's an example of a `Run` script step in a Harness CI stage:
```yaml
- step:
    type: Run
    name: Build .NET Application
    identifier: build_dotnet_app
    spec:
      connectorRef: <YOUR_DOCKER_CONNECTOR_IF_NEEDED_FOR_PULLING_BASE_IMAGE> # e.g., Docker Hub
      image: harness/ci-addon:latest # Or any image with Docker client installed
      shell: Sh
      command: |
        echo "Building Docker image for StarWarsCore..."
        docker build -t starwars-core-build -f StarWarsCore/Dockerfile StarWarsCore/

        echo "Creating container to extract artifact..."
        docker create --name sw_build_container starwars-core-build

        echo "Copying published artifact from container..."
        # Ensure the target directory exists on the CI agent
        mkdir -p /harness/published_app
        docker cp sw_build_container:/app/publish /harness/published_app/win-x64

        echo "Cleaning up container..."
        docker rm sw_build_container

        echo "Listing published artifact:"
        ls -la /harness/published_app/win-x64

        # At this point, /harness/published_app/win-x64 contains your StarWarsCore.exe
        # and any other files if PublishSingleFile was false.
        # This directory should then be uploaded as an artifact.
```
*   **Explanation:**
    *   The script builds a Docker image named `starwars-core-build` using the provided `Dockerfile`.
    *   It then creates a temporary container from this image.
    *   `docker cp` is used to copy the `/app/publish` directory (which contains `StarWarsCore.exe`) from the container to a known location on the CI agent (e.g., `/harness/published_app/win-x64`).
    *   This artifact (`/harness/published_app/win-x64` directory or specifically `StarWarsCore.exe` from it) should then be uploaded using Harness's artifact storage capabilities or other artifact management tools.

### 2. Artifact Transfer to Windows VM

Once the build artifact (`StarWarsCore.exe` or the `publish` directory) is available from your CI pipeline (e.g., stored in Harness's artifact storage, JFrog Artifactory, AWS S3, etc.):

*   **Download/Transfer:** Use the appropriate Harness steps or deployment scripts to transfer this artifact to your target Windows VM. The exact method depends on your infrastructure and Harness setup. Common methods include:
    *   Using Harness Delegate with access to the Windows VM to download from an artifact repository.
    *   Secure Copy (SCP) or SFTP if the Windows VM has an SSH server.
    *   Copying from a shared network drive accessible by both CI and the VM.
    *   Using cloud provider tools (e.g., Azure Pipelines artifacts, AWS CodeDeploy with S3).

### 3. Deploying and Running on Windows VM

Once the artifact (e.g., `StarWarsCore.exe`) is on the Windows VM:

1.  Place `StarWarsCore.exe` (and any accompanying files if not published as a single file) into a desired directory on the VM (e.g., `C:\apps\StarWarsCore\`).
2.  You can then run the application as described in the "Option 2: Publishing a Self-Contained Deployment for Windows" section, step 4: "Run on Windows VM". This typically involves double-clicking `StarWarsCore.exe` or running it from PowerShell/CMD.
3.  For robust deployment, consider running it as a Windows Service using tools like `NSSM` (Non-Sucking Service Manager) or by integrating with IIS if more advanced hosting features are required (though for a simple static site, a self-contained .exe is often sufficient).

This provides a general workflow. You'll need to adapt the specifics (connector names, paths, artifact storage details) to your Harness and environment setup.
