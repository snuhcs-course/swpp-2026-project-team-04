param([Parameter(Mandatory = $true)][string]$VmServiceUri)
$ErrorActionPreference = 'Stop'
$endpoint = [uri]$VmServiceUri
if ($endpoint.Host -notin @('127.0.0.1','localhost')) { throw 'Debug service must be loopback-only' }
$base = $VmServiceUri.TrimEnd('/') + '/'
function Invoke-Vm([string]$method, [hashtable]$parameters) {
    $pairs = foreach ($key in $parameters.Keys) {
        [uri]::EscapeDataString($key) + '=' + [uri]::EscapeDataString([string]$parameters[$key])
    }
    $response = Invoke-RestMethod -Uri ($base + $method + '?' + ($pairs -join '&')) -TimeoutSec 20
    if ($response.error) { throw ($response.error | ConvertTo-Json -Depth 4 -Compress) }
    return $response.result
}
$isolate = ((Invoke-Vm 'getVM' @{}).isolates | Where-Object name -eq 'main').id
$classes = (Invoke-Vm 'getClassList' @{isolateId=$isolate}).classes
$classId = ($classes | Where-Object name -eq 'SecureTokenStore').id
$instance = (Invoke-Vm 'getInstances' @{isolateId=$isolate;objectId=$classId;limit=1}).instances[0]
if (-not $instance.id) { throw 'App SecureTokenStore was not found' }
# A unique, non-secret diagnostic key only. Never read/write the user's session.
$probe = 'gymrats.diagnostic.' + [guid]::NewGuid().ToString('N')
$expression = "(() async { const key = '$probe'; try { await _storage.write(key: key, value: 'nonsecret-probe'); final value = await _storage.read(key: key); await _storage.delete(key: key); final remaining = await _storage.containsKey(key: key); return value == 'nonsecret-probe' && !remaining ? 'SECURE_STORAGE_ROUNDTRIP_OK' : 'SECURE_STORAGE_MISMATCH'; } catch(e) { try { await _storage.delete(key: key); } catch(_) {} return e.runtimeType.toString() + ': ' + e.toString(); } })()"
$future = Invoke-Vm 'evaluate' @{isolateId=$isolate;targetId=$instance.id;expression=$expression}
if ($future.type -eq 'Error') { throw $future.message }
for ($attempt = 0; $attempt -lt 50; $attempt++) {
    $object = Invoke-Vm 'getObject' @{isolateId=$isolate;objectId=$future.id}
    $result = ($object.fields | Where-Object { $_.decl.name -eq '_resultOrListeners' }).value
    if ($result.kind -eq 'String') {
        $text = (Invoke-Vm 'getObject' @{isolateId=$isolate;objectId=$result.id}).valueAsString
        if ($text -ne 'SECURE_STORAGE_ROUNDTRIP_OK') { throw $text }
        Write-Output $text
        exit 0
    }
    Start-Sleep -Milliseconds 100
}
throw 'Secure storage diagnostic timed out'
