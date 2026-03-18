#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# ──────────────────────────────────────────────────────────────────────────────
# deploy-war.ps1
# Deploys petpoll.war to the running Tomcat instance and waits for the
# application context to become available at http://localhost:8595/petpoll/
# ──────────────────────────────────────────────────────────────────────────────

$ServiceName  = "Tomcat10"
$TomcatDir    = "C:\tomcat"
$WarSource    = "C:\vagrant\webapp\target\petpoll.war"
$WarDest      = "$TomcatDir\webapps\petpoll.war"
$AppUrl       = "http://localhost:8595/petpoll/"
$TimeoutSecs  = 30

# ── Step 1: Stop Tomcat ───────────────────────────────────────────────────────
Write-Host "==> Stopping $ServiceName"
Stop-Service -Name $ServiceName -Force
Write-Host "  Service stopped"

# ── Step 2: Remove any existing petpoll deployment ───────────────────────────
Write-Host "==> Removing existing petpoll deployments from webapps"
Get-ChildItem "$TomcatDir\webapps" |
    Where-Object { $_.Name -like "petpoll*" } |
    ForEach-Object {
        Write-Host "  Removing $($_.FullName)"
        Remove-Item -Recurse -Force $_.FullName
    }

# ── Step 3: Copy new WAR ──────────────────────────────────────────────────────
Write-Host "==> Copying $WarSource -> $WarDest"
if (-not (Test-Path $WarSource)) {
    throw "WAR file not found at '$WarSource'. Run 'mvn package -DskipTests' in webapp/ first."
}
Copy-Item -Path $WarSource -Destination $WarDest -Force
Write-Host "  WAR copied"

# ── Step 4: Start Tomcat ──────────────────────────────────────────────────────
Write-Host "==> Starting $ServiceName"
Start-Service -Name $ServiceName
Write-Host "  Service started"

# ── Step 5: Wait for application to respond HTTP 200 ─────────────────────────
Write-Host "==> Waiting up to ${TimeoutSecs}s for $AppUrl to return HTTP 200"
$deadline = (Get-Date).AddSeconds($TimeoutSecs)
$ready    = $false

while ((Get-Date) -lt $deadline) {
    try {
        $response = Invoke-WebRequest -Uri $AppUrl -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "  HTTP 200 received — application is up"
            $ready = $true
            break
        }
    }
    catch {
        # Not ready yet; keep polling
    }
    Start-Sleep -Seconds 2
}

if (-not $ready) {
    throw "Application at '$AppUrl' did not return HTTP 200 within ${TimeoutSecs} seconds."
}

Write-Host "==> Deployment complete — petpoll is running at $AppUrl"
