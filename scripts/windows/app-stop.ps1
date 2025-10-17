param(
  [int]$Port = 5274
)

try {
  $conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($conns) {
    $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($p in $pids) {
      Write-Host ("Deteniendo Flutter web-server en puerto {0} (PID {1})..." -f $Port, $p)
      Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
    }
    Write-Host "App detenida."
  } else {
    Write-Host "No hay proceso escuchando en :$Port."
  }
} catch {
  Write-Warning ("No pude detener la app: {0}" -f $_.Exception.Message)
}
