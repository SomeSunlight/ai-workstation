#Requires -Version 7.4
# Full S02 gateway identity preparation test, on disposable Windows user files.
# No real keys, Caddyfile, Dispatcher, native model or applications involved.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$folder=Join-Path $env:RUNNER_TEMP ('aiw-s02-three-' + [guid]::NewGuid().ToString('N'))
$legacy=Join-Path $folder 'legacy-existing-secret.dpapi'
$env:AIW_SERVICES_DIR=$folder
try{
    New-Item -ItemType Directory -Path $folder -Force|Out-Null
    & (Join-Path $root 'bootstrap/windows/Services.ps1') init
    foreach($name in @('goose-wsl','webui-wsl','webui-host')){
        & (Join-Path $root 'bootstrap/windows/Services.ps1') client add $name --policy passthrough
    }
    'synthetic-legacy-test-credential'|ConvertTo-SecureString -AsPlainText -Force|
        ConvertFrom-SecureString|Set-Content -LiteralPath $legacy
    & (Join-Path $root 'bootstrap/windows/Services.ps1') client import-dpapi home-gateway `
        --from-file $legacy --policy passthrough
    & (Join-Path $root 'bootstrap/windows/Services.ps1') client render
    $path=Join-Path $folder 'clients.json'
    $doc=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
    $ids=@($doc.clients|ForEach-Object {$_.id})
    if(($ids -join ',') -cne 'goose-wsl,webui-wsl,webui-host,home-gateway'){
        throw 'The private S02 digest-only file is missing expected distinct clients.'
    }
    $digests=@($doc.clients|ForEach-Object {$_.token_sha256})
    if(@($digests|Select-Object -Unique).Count -ne 4 -or
        @($digests|Where-Object {$_ -cnotmatch '^[a-f0-9]{64}$'}).Count -ne 0){
        throw 'Generated S02 digests missing or duplicated.'
    }
    if((Get-Content -LiteralPath $path -Raw) -match 'synthetic-legacy-test-credential'){
        throw 'Plaintext legacy token leaked to digest registry.'
    }
    foreach($name in @('goose-wsl','webui-wsl','webui-host')){
        if(-not (Test-Path -LiteralPath (Join-Path $folder ('secrets/'+$name+'.dpapi')))){
            throw 'Missing DPAPI original for independently generated client.'
        }
    }
    $before=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    & (Join-Path $root 'bootstrap/windows/Services.ps1') client render
    $after=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if($before -cne $after){throw 'Idempotent S02 render changed client digests.'}
    Write-Host '[PASS] Three distinct original DPAPI keys and transitional legacy key; four unique digest-only entries.'
}
finally{
    Remove-Item Env:AIW_SERVICES_DIR -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
}
