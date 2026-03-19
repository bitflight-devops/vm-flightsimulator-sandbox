#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# ──────────────────────────────────────────────────────────────────────────────
# provision-tomcat.ps1
# Installs Eclipse Temurin 21 JDK, Apache Tomcat 10.1 as a Windows service on
# port 8595, opens the firewall, and optionally deploys petpoll.war if built.
# ──────────────────────────────────────────────────────────────────────────────

$TemurinUrl  = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.3%2B9/OpenJDK21U-jdk_x64_windows_hotspot_21.0.3_9.msi"
$TomcatUrl   = "https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.24/bin/apache-tomcat-10.1.24-windows-x64.zip"
$TomcatDir   = "C:\tomcat"
$TomcatPort  = 8595
$ServiceName = "Tomcat10"
$WarSource   = "C:\vagrant\webapp\target\petpoll.war"

# ── Step 1: Install Eclipse Temurin 21 JDK ───────────────────────────────────
Write-Host "==> Downloading Eclipse Temurin 21 JDK MSI"
$TemurinMsi = "$env:TEMP\temurin21.msi"
Invoke-WebRequest -Uri $TemurinUrl -OutFile $TemurinMsi -UseBasicParsing

Write-Host "==> Installing Temurin 21 JDK silently"
$installArgs = @(
    "/i", $TemurinMsi,
    "/quiet",
    "/norestart",
    "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome"
)
Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -NoNewWindow

Write-Host "==> Setting JAVA_HOME machine-wide"
# Temurin MSI sets JAVA_HOME; read it back and ensure PATH contains bin
$javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
if (-not $javaHome) {
    # Fallback: locate the install directory
    $javaHome = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory |
                 Where-Object { $_.Name -like "jdk-21*" } |
                 Select-Object -First 1).FullName
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")
}
Write-Host "  JAVA_HOME = $javaHome"

$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
if ($machinePath -notlike "*$javaHome\bin*") {
    [System.Environment]::SetEnvironmentVariable(
        "PATH", "$machinePath;$javaHome\bin", "Machine"
    )
}
# Refresh current session
$env:JAVA_HOME = $javaHome
$env:PATH      = "$env:PATH;$javaHome\bin"

# ── Step 2: Download and expand Tomcat 10.1 ──────────────────────────────────
Write-Host "==> Downloading Apache Tomcat 10.1.24"
$TomcatZip = "$env:TEMP\tomcat.zip"
Invoke-WebRequest -Uri $TomcatUrl -OutFile $TomcatZip -UseBasicParsing

Write-Host "==> Expanding Tomcat to $TomcatDir"
if (Test-Path $TomcatDir) {
    Remove-Item -Recurse -Force $TomcatDir
}
# Zip contains a single top-level directory; extract then rename
$expandTarget = "$env:TEMP\tomcat-expand"
Expand-Archive -Path $TomcatZip -DestinationPath $expandTarget -Force
$extractedDir = (Get-ChildItem $expandTarget -Directory | Select-Object -First 1).FullName
Move-Item -Path $extractedDir -Destination $TomcatDir

# ── Step 3: Configure connector port 8595 in server.xml ──────────────────────
Write-Host "==> Configuring Tomcat connector port to $TomcatPort"
$serverXml = "$TomcatDir\conf\server.xml"
(Get-Content $serverXml) -replace 'port="8080"', "port=`"$TomcatPort`"" |
    Set-Content $serverXml

# ── Step 4: Install Tomcat as a Windows service ───────────────────────────────
Write-Host "==> Installing Tomcat as Windows service '$ServiceName'"
$serviceBat = "$TomcatDir\bin\service.bat"
# service.bat requires JAVA_HOME and CATALINA_HOME in the environment
$env:CATALINA_HOME = $TomcatDir
& cmd.exe /c "`"$serviceBat`" install $ServiceName"
if ($LASTEXITCODE -ne 0) {
    throw "service.bat install exited with code $LASTEXITCODE"
}

# ── Step 5: Configure service to start automatically and start it ─────────────
Write-Host "==> Setting $ServiceName to start automatically"
Set-Service -Name $ServiceName -StartupType Automatic

Write-Host "==> Starting $ServiceName"
Start-Service -Name $ServiceName

# ── Step 6: Open firewall port 8595 ──────────────────────────────────────────
Write-Host "==> Opening firewall port $TomcatPort (TCP inbound)"
$fwRuleName = "Tomcat $TomcatPort TCP"
if (-not (Get-NetFirewallRule -DisplayName $fwRuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName  $fwRuleName `
        -Direction    Inbound `
        -Protocol     TCP `
        -LocalPort    $TomcatPort `
        -Action       Allow `
        -Profile      Any | Out-Null
}

# ── Step 7: Deploy WAR if already built ──────────────────────────────────────
if (Test-Path $WarSource) {
    Write-Host "==> Deploying petpoll.war to Tomcat webapps"
    try {
        Copy-Item -Path $WarSource -Destination "$TomcatDir\webapps\petpoll.war" -Force
        Write-Host "  WAR deployed successfully"
    } catch {
        Write-Host "  WARNING: WAR copy failed — $($_.Exception.Message)"
    }
} else {
    Write-Host "==> WAR not found at '$WarSource' — skipping deployment (build not yet complete)"
}

# ── Step 8: Suppress Edge first-run prompts ───────────────────────────────────
Write-Host "==> Suppressing Microsoft Edge first-run experience via registry"
$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (-not (Test-Path $edgePolicyPath)) {
    New-Item -Path $edgePolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $edgePolicyPath -Name "HideFirstRunExperience" -Value 1       -Type DWord
Set-ItemProperty -Path $edgePolicyPath -Name "AutoImportAtFirstRun"   -Value 0       -Type DWord

Write-Host "==> Tomcat 10.1 provisioning complete — listening on port $TomcatPort"
