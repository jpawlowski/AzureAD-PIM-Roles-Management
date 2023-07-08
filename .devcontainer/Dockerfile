FROM mcr.microsoft.com/devcontainers/powershell:latest
RUN pwsh \
  -NoLogo \
  -NoProfile \
  -Command " \
  \$ErrorActionPreference = 'Stop' ; \
  \$ProgressPreference = 'SilentlyContinue' ; \
  Install-Module Microsoft.Graph -MinimumVersion 2.0"
