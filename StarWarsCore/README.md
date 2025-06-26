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
