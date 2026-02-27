name: ZaldoPrinter CI (Windows)

on:
  push:
    branches: [ "main", "master", "develop" ]
    paths:
      - "tools/ZaldoPrinter/**"
      - ".github/workflows/main.yml"
  pull_request:
    branches: [ "main", "master", "develop" ]
    paths:
      - "tools/ZaldoPrinter/**"
      - ".github/workflows/main.yml"
  workflow_dispatch:

env:
  DOTNET_VERSION: "8.0.x"
  CONFIGURATION: "Release"
  RUNTIME: "win-x64"

  ZP_SERVICE_PROJECT: "tools/ZaldoPrinter/src/ZaldoPrinter.Service/ZaldoPrinter.Service.csproj"
  ZP_CONFIG_PROJECT: "tools/ZaldoPrinter/src/ZaldoPrinter.ConfigApp/ZaldoPrinter.ConfigApp.csproj"
  ZP_INNO_SCRIPT: "tools/ZaldoPrinter/installer/ZaldoPrinter.iss"

  ZP_PUBLISH_DIR: "tools/ZaldoPrinter/out/publish"
  ZP_INSTALLER_DIR: "tools/ZaldoPrinter/out/installer"
  SETUP_EXE_NAME: "ZaldoPrinterSetup.exe"

jobs:
  build:
    runs-on: windows-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Publish Service (win-x64)
        shell: pwsh
        run: >
          dotnet publish "${{ env.ZP_SERVICE_PROJECT }}"
          -c ${{ env.CONFIGURATION }}
          -r ${{ env.RUNTIME }}
          --self-contained true
          /p:PublishSingleFile=true
          /p:IncludeNativeLibrariesForSelfExtract=true
          -o "${{ env.ZP_PUBLISH_DIR }}"

      - name: Publish ConfigApp (win-x64)
        shell: pwsh
        run: >
          dotnet publish "${{ env.ZP_CONFIG_PROJECT }}"
          -c ${{ env.CONFIGURATION }}
          -r ${{ env.RUNTIME }}
          --self-contained true
          /p:PublishSingleFile=true
          /p:IncludeNativeLibrariesForSelfExtract=true
          -o "${{ env.ZP_PUBLISH_DIR }}"

      - name: Remove debug symbols (.pdb)
        shell: pwsh
        run: |
          if (Test-Path "${{ env.ZP_PUBLISH_DIR }}") {
            Get-ChildItem -Path "${{ env.ZP_PUBLISH_DIR }}" -Recurse -Filter *.pdb |
              Remove-Item -Force -ErrorAction SilentlyContinue
          }

      - name: Install Inno Setup
        shell: pwsh
        run: choco install innosetup -y

      - name: Debug .iss (first 160 lines)
        shell: pwsh
        run: |
          $p = "${{ env.ZP_INNO_SCRIPT }}"
          Write-Host "=== SHOWING $p (first 160 lines) ==="
          Get-Content $p | Select-Object -First 160 | ForEach-Object { Write-Host $_ }

      - name: Assert .iss has no invalid flags
        shell: pwsh
        run: |
          $p = "${{ env.ZP_INNO_SCRIPT }}"
          $c = Get-Content $p -Raw
          if ($c -match "skipifdoesntexist") { throw "ISS contains invalid flag: skipifdoesntexist" }
          if ($c -match "waituntilterminated") { throw "ISS contains invalid flag: waituntilterminated" }
          Write-Host "OK: no invalid flags found"

      - name: Build Installer (ISCC)
        shell: pwsh
        run: |
          $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
          if (!(Test-Path $iscc)) { throw "ISCC not found at $iscc" }
          & $iscc "${{ env.ZP_INNO_SCRIPT }}"

      - name: Verify installer exists
        shell: pwsh
        run: |
          $setup = Join-Path "${{ env.ZP_INSTALLER_DIR }}" "${{ env.SETUP_EXE_NAME }}"
          if (!(Test-Path $setup)) {
            Write-Host "Publish dir contents:"
            Get-ChildItem -Force "${{ env.ZP_PUBLISH_DIR }}" -ErrorAction SilentlyContinue
            Write-Host "Installer dir contents:"
            Get-ChildItem -Force "${{ env.ZP_INSTALLER_DIR }}" -ErrorAction SilentlyContinue
            throw "Installer not found: $setup"
          }

      - name: Generate SHA256
        shell: pwsh
        run: |
          $setup = Join-Path "${{ env.ZP_INSTALLER_DIR }}" "${{ env.SETUP_EXE_NAME }}"
          $hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()
          Set-Content -Path (Join-Path "${{ env.ZP_INSTALLER_DIR }}" "${{ env.SETUP_EXE_NAME }}.sha256") -Value $hash

      - name: Upload installer artifact
        uses: actions/upload-artifact@v4
        with:
          name: ZaldoPrinterSetup
          path: |
            tools/ZaldoPrinter/out/installer/ZaldoPrinterSetup.exe
            tools/ZaldoPrinter/out/installer/ZaldoPrinterSetup.exe.sha256

  release:
    if: startsWith(github.ref, 'refs/tags/zp-v')
    needs: build
    runs-on: windows-latest

    steps:
      - name: Download installer artifact
        uses: actions/download-artifact@v4
        with:
          name: ZaldoPrinterSetup
          path: dist

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            dist/ZaldoPrinterSetup.exe
            dist/ZaldoPrinterSetup.exe.sha256
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
