FROM mcr.microsoft.com/powershell:latest
RUN pwsh \
  -NoLogo \
  -NoProfile \
  -Command " \
  \$ErrorActionPreference = 'Stop' ; \
  \$ProgressPreference = 'SilentlyContinue' ; \
  Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted ; \
  Install-Module Microsoft.Graph -Verbose -MinimumVersion 2.0"
