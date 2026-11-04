<#
.SYNOPSIS
    Termina de configurar Jenkins para el proyecto Adopet: instala los plugins
    necesarios, crea (o actualiza) el job de pipeline y lanza el primer build.

.DESCRIPTION
    Requiere un API token del usuario administrador de Jenkins. Para generarlo:
    Jenkins -> (tu usuario, arriba a la derecha) -> Security -> API Token ->
    Add new Token -> Generate.

.EXAMPLE
    .\setup-jenkins.ps1 -JenkinsUser jenkins -JenkinsToken 11abc...

.EXAMPLE
    # Usar el repositorio local en lugar de GitHub
    .\setup-jenkins.ps1 -JenkinsUser jenkins -JenkinsToken 11abc... -RepoUrl 'C:/Users/Pablo/Documents/8-sem/Adopet'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $JenkinsUser,
    [Parameter(Mandatory = $true)] [string] $JenkinsToken,
    [string] $JenkinsUrl = 'http://localhost:8080',
    [string] $JobName    = 'Adopet-CI',
    [string] $RepoUrl    = 'https://github.com/DiegoVargasZ/Adopet.git',
    [string] $Branch     = 'main',
    [switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'
$JenkinsUrl = $JenkinsUrl.TrimEnd('/')
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path

# Plugins que el Jenkinsfile y el job necesitan.
$requiredPlugins = @(
    'git',                  # checkout del repositorio (Pipeline script from SCM)
    'workflow-aggregator',  # suite completa de Pipeline
    'pipeline-stage-view',  # vista grafica de etapas
    'junit',                # reporte de pruebas
    'timestamper',          # marcas de tiempo en consola
    'ws-cleanup'            # limpieza de workspace
)

# --- autenticacion basica con el API token ---
$pair    = '{0}:{1}' -f $JenkinsUser, $JenkinsToken
$basic   = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$headers = @{ Authorization = $basic }

function Invoke-Jenkins {
    param(
        [string] $Path,
        [string] $Method = 'GET',
        [object] $Body,
        [string] $ContentType,
        [hashtable] $ExtraHeaders
    )
    $h = $headers.Clone()
    if ($ExtraHeaders) { foreach ($k in $ExtraHeaders.Keys) { $h[$k] = $ExtraHeaders[$k] } }

    $req = @{
        Uri             = "$JenkinsUrl$Path"
        Method          = $Method
        Headers         = $h
        UseBasicParsing = $true
        TimeoutSec      = 120
    }
    if ($PSBoundParameters.ContainsKey('Body'))        { $req['Body'] = $Body }
    if ($PSBoundParameters.ContainsKey('ContentType')) { $req['ContentType'] = $ContentType }
    Invoke-WebRequest @req
}

function Get-Crumb {
    try {
        $r = Invoke-Jenkins -Path '/crumbIssuer/api/json'
        $j = $r.Content | ConvertFrom-Json
        return @{ $j.crumbRequestField = $j.crumb }
    } catch {
        Write-Verbose 'Sin crumb issuer; se continua sin CSRF token.'
        return @{}
    }
}

function Wait-JenkinsUp {
    param([int] $TimeoutMinutes = 5)
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        try {
            Invoke-Jenkins -Path '/api/json' | Out-Null
            return $true
        } catch { }
    }
    return $false
}

Write-Host '==> Verificando conexion con Jenkins...' -ForegroundColor Cyan
$whoami = (Invoke-Jenkins -Path '/me/api/json').Content | ConvertFrom-Json
Write-Host ('    Autenticado como: {0}' -f $whoami.id) -ForegroundColor Green

$crumb = Get-Crumb

# ---------------------------------------------------------------- plugins ----
Write-Host '==> Revisando plugins instalados...' -ForegroundColor Cyan
$installed      = ((Invoke-Jenkins -Path '/pluginManager/api/json?depth=1').Content | ConvertFrom-Json).plugins
$installedNames = @($installed | ForEach-Object { $_.shortName })

$missing = @()
foreach ($p in $requiredPlugins) {
    if ($installedNames -notcontains $p) { $missing += $p }
}

if ($missing.Count -eq 0) {
    Write-Host '    Todos los plugins necesarios ya estan instalados.' -ForegroundColor Green
} else {
    Write-Host ('    Faltan: {0}' -f ($missing -join ', ')) -ForegroundColor Yellow

    Write-Host '==> Actualizando catalogo de plugins...' -ForegroundColor Cyan
    try {
        Invoke-Jenkins -Path '/pluginManager/checkUpdatesServer' -Method POST -ExtraHeaders $crumb | Out-Null
    } catch {
        Write-Host '    (no se pudo refrescar el catalogo; se intenta instalar igual)' -ForegroundColor Yellow
    }

    $installTags = ($missing | ForEach-Object { '<install plugin="' + $_ + '@latest" />' }) -join ''
    $xml = '<jenkins>' + $installTags + '</jenkins>'

    Write-Host '==> Instalando plugins (incluye dependencias)...' -ForegroundColor Cyan
    $crumb = Get-Crumb
    Invoke-Jenkins -Path '/pluginManager/installNecessaryPlugins' -Method POST -Body $xml -ContentType 'text/xml' -ExtraHeaders $crumb | Out-Null

    # Espera a que el update center termine.
    $deadline = (Get-Date).AddMinutes(10)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        $uc = (Invoke-Jenkins -Path '/updateCenter/api/json?depth=1').Content | ConvertFrom-Json
        $failed  = @($uc.jobs | Where-Object { $_.status -and $_.status.type -eq 'Failure' })
        if ($failed.Count -gt 0) {
            $names = ($failed | ForEach-Object { $_.name }) -join ', '
            throw "Fallo la instalacion de: $names"
        }
        $pending = @($uc.jobs | Where-Object {
            $_.status -and @('Success', 'Failure', 'Skipped') -notcontains $_.status.type
        })
        if ($pending.Count -eq 0) { break }
        Write-Host ('    pendientes: {0}' -f (($pending | ForEach-Object { $_.name }) -join ', '))
    }
    Write-Host '    Plugins descargados.' -ForegroundColor Green

    # Algunos plugins requieren reinicio para quedar activos.
    $after    = ((Invoke-Jenkins -Path '/pluginManager/api/json?depth=1').Content | ConvertFrom-Json).plugins
    $inactive = @($after | Where-Object { $missing -contains $_.shortName -and -not $_.active })

    if ($inactive.Count -gt 0) {
        Write-Host '==> Reinicio seguro de Jenkins para activar los plugins...' -ForegroundColor Cyan
        $crumb = Get-Crumb
        try {
            Invoke-Jenkins -Path '/safeRestart' -Method POST -ExtraHeaders $crumb | Out-Null
        } catch {
            Write-Host '    (la peticion de reinicio corto la conexion; es normal)' -ForegroundColor Yellow
        }
        if (-not (Wait-JenkinsUp -TimeoutMinutes 5)) {
            throw 'Jenkins no volvio a responder tras el reinicio.'
        }
        Write-Host '    Jenkins reiniciado y disponible.' -ForegroundColor Green
    }
    $crumb = Get-Crumb
}

# -------------------------------------------------------------------- job ----
Write-Host ("==> Configurando el job '{0}'..." -f $JobName) -ForegroundColor Cyan

$templatePath = Join-Path $scriptDir 'job-config.xml'
if (-not (Test-Path $templatePath)) { throw "No se encontro $templatePath" }

$config = (Get-Content -Path $templatePath -Raw -Encoding UTF8).Replace('@@REPO_URL@@', $RepoUrl).Replace('@@BRANCH@@', $Branch)
$bytes  = [Text.Encoding]::UTF8.GetBytes($config)

$crumb  = Get-Crumb
$exists = $false
try {
    Invoke-Jenkins -Path ('/job/{0}/api/json' -f $JobName) | Out-Null
    $exists = $true
} catch { }

if ($exists) {
    Invoke-Jenkins -Path ('/job/{0}/config.xml' -f $JobName) -Method POST -Body $bytes -ContentType 'application/xml' -ExtraHeaders $crumb | Out-Null
    Write-Host '    Job actualizado.' -ForegroundColor Green
} else {
    Invoke-Jenkins -Path ('/createItem?name={0}' -f $JobName) -Method POST -Body $bytes -ContentType 'application/xml' -ExtraHeaders $crumb | Out-Null
    Write-Host '    Job creado.' -ForegroundColor Green
}

Write-Host ('    Repositorio: {0} (rama {1})' -f $RepoUrl, $Branch)
Write-Host ('    URL: {0}/job/{1}/' -f $JenkinsUrl, $JobName)

# ------------------------------------------------------------------ build ----
if ($SkipBuild) {
    Write-Host '==> Se omite el build inicial (-SkipBuild).' -ForegroundColor Yellow
    return
}

Write-Host '==> Lanzando el primer build...' -ForegroundColor Cyan
$crumb    = Get-Crumb
$queue    = Invoke-Jenkins -Path ('/job/{0}/build' -f $JobName) -Method POST -ExtraHeaders $crumb
$queueUrl = $queue.Headers['Location']
if (-not $queueUrl) { throw 'Jenkins no devolvio la URL de la cola.' }

$buildNumber = $null
$deadline    = (Get-Date).AddMinutes(5)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 4
    $qi = (Invoke-WebRequest -Uri ($queueUrl.TrimEnd('/') + '/api/json') -Headers $headers -UseBasicParsing -TimeoutSec 60).Content | ConvertFrom-Json
    if ($qi.cancelled) { throw 'El build fue cancelado en la cola.' }
    if ($qi.executable -and $qi.executable.number) {
        $buildNumber = $qi.executable.number
        break
    }
    if ($qi.why) { Write-Host ('    en cola: {0}' -f $qi.why) }
}
if (-not $buildNumber) { throw 'El build no arranco (sigue en la cola).' }

Write-Host ('    Build #{0}: {1}/job/{2}/{0}/console' -f $buildNumber, $JenkinsUrl, $JobName) -ForegroundColor Green
Write-Host '    Esperando a que termine (puede tardar varios minutos)...'

$deadline = (Get-Date).AddMinutes(60)
$result   = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 15
    $b = (Invoke-Jenkins -Path ('/job/{0}/{1}/api/json' -f $JobName, $buildNumber)).Content | ConvertFrom-Json
    if (-not $b.building) {
        $result = $b.result
        break
    }
}

if (-not $result) {
    Write-Host '    El build sigue corriendo; revisalo en la consola web.' -ForegroundColor Yellow
    return
}

$color = 'Red'
if ($result -eq 'SUCCESS')  { $color = 'Green' }
if ($result -eq 'UNSTABLE') { $color = 'Yellow' }
Write-Host ('==> Build #{0}: {1}' -f $buildNumber, $result) -ForegroundColor $color

if ($result -ne 'SUCCESS') {
    Write-Host '--- ultimas lineas de consola ---' -ForegroundColor Yellow
    $log = (Invoke-Jenkins -Path ('/job/{0}/{1}/consoleText' -f $JobName, $buildNumber)).Content
    ($log -split "`n" | Select-Object -Last 40) | ForEach-Object { Write-Host $_ }
    exit 1
}
