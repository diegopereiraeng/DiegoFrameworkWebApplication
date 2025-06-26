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

# The final stage is not strictly necessary if Harness CI directly uses the build-env
# or copies artifacts from it. However, if a smaller image with just the artifact
# were desired for some reason, it could be added here.
# For this use case (CI build), the build-env stage contains the artifact in /app/publish.

# To get the artifact from the build container (example commands, not part of Dockerfile):
# 1. Build the image: docker build -t starwars-build .
# 2. Create a container: docker create --name sw_container starwars-build
# 3. Copy the artifact out: docker cp sw_container:/app/publish ./publish_output
# 4. Remove the container: docker rm sw_container
