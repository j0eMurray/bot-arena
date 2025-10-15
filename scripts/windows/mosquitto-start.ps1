param(
  [string]$MosqExe    = 'C:\Program Files\mosquitto\mosquitto.exe',
  [string]$MosqPasswd = 'C:\Program Files\mosquitto\mosquitto_passwd.exe',
  [string]$ConfDir    = "$env:LOCALAPPDATA\mosquitto",
  [string]$User       = 'iot_ingest',
  [string]$Password   = 'changeme'
)

if (-not (Test-Path $MosqExe)) {
  $cmd = Get-Command mosquitto -ErrorAction SilentlyContinue
  if ($cmd) { $MosqExe = $cmd.Source }
}
if (-not (Test-Path $MosqPasswd)) {
  $cmd = Get-Command mosquitto_passwd -ErrorAction SilentlyContinue
  if ($cmd) { $MosqPasswd = $cmd.Source }
}
if (-not (Test-Path $MosqExe) -or -not (Test-Path $MosqPasswd)) {
  Write-Error "No encuentro Mosquitto. Ajusta -MosqExe / -MosqPasswd o reinstala."
  exit 1
}

New-Item -ItemType Directory -Force -Path $ConfDir | Out-Null
try {
  $probe = Join-Path $ConfDir ".__write_probe"
  Set-Content -Path $probe -Value "ok" -Encoding ascii
  Remove-Item $probe -Force
} catch {
  Write-Error "No puedo escribir en $ConfDir. Usa -ConfDir o abre consola con permisos."
  exit 1
}

$passwdPath = Join-Path $ConfDir 'passwd'
if (Test-Path $passwdPath -PathType Container) { Remove-Item $passwdPath -Force -Recurse }

if (-not (Test-Path $passwdPath -PathType Leaf)) {
  & $MosqPasswd -c -b $passwdPath $User $Password
} else {
  & $MosqPasswd -b $passwdPath $User $Password
}
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $passwdPath -PathType Leaf)) {
  Write-Error ("Fallo creando/actualizando passwd en {0}" -f $passwdPath)
  exit 1
}

$confPath = Join-Path $ConfDir 'mosquitto.conf'
@"
listener 1883 localhost
allow_anonymous false
password_file $passwdPath
persistence true
persistence_location $ConfDir\
"@ | Out-File -Encoding ascii $confPath

Write-Host ("Iniciando Mosquitto en localhost:1883 con config {0} ..." -f $confPath)
$proc = Start-Process -FilePath $MosqExe -ArgumentList @('-v','-c',$confPath) -NoNewWindow -PassThru
$pidPath = Join-Path $ConfDir 'mosquitto.pid'
$proc.Id | Out-File -Encoding ascii $pidPath
Write-Host ("Mosquitto PID: {0} (guardado en {1})" -f $proc.Id, $pidPath)
