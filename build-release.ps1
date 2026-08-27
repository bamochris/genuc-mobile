<#
    Construction de l'APK release GENUC Mobile — URL de production figée.

    Pourquoi ce script existe (26/08/2026)
    ─────────────────────────────────────
    L'APK du 26/08 a été construit à la main avec
    `--dart-define=API_BASE_URL=https://genucapplication-production.up.railway.app`,
    le domaine public du SERVICE BACKEND. L'edge de Railway rend ce domaine en
    « 429 rate limited » sur toutes les routes, en permanence. L'application
    traduisant tout 429 en « Trop de tentatives », l'APK paraissait vivant et
    refusait chaque connexion — sans laisser la moindre trace dans les journaux
    du serveur, puisque la requête n'atteignait jamais l'application.

    Seul `https://genuc.up.railway.app` (service frontend nginx, qui proxifie
    `/api/` et `/uploads/` vers le backend par le réseau privé Railway) doit
    être livré. On ne le retape donc plus : il est figé ici, et vérifié DANS le
    binaire produit avant d'annoncer quoi que ce soit.

    Usage :  pwsh -File .\build-release.ps1
             pwsh -File .\build-release.ps1 -ApiBaseUrl https://autre.example  (rare)
#>

[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'https://genuc.up.railway.app',
    [string]$FlutterBat = 'C:\tools\flutter\bin\flutter.bat'
)

$ErrorActionPreference = 'Stop'
$racine = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $racine

# ─── PATH court et propre ────────────────────────────────────────────────
# Le PATH de cette machine dépasse 10 000 caractères ; cmd.exe tronque au-delà
# de ~2047 et ne retrouve alors plus `where.exe`. `flutter.bat` échoue en
# « Unable to find git in your PATH » — message qui n'a rien à voir avec git.
$env:PATH = @(
    'C:\Windows\System32'
    'C:\Windows'
    'C:\Windows\System32\Wbem'
    'C:\Windows\System32\WindowsPowerShell\v1.0'
    'C:\Program Files\PowerShell\7'
    'C:\Program Files\Git\cmd'
    'C:\tools\flutter\bin'
    'C:\Program Files\Java\jdk-21.0.10\bin'
) -join ';'

Write-Host "→ Construction release, API_BASE_URL = $ApiBaseUrl" -ForegroundColor Cyan

& $FlutterBat build apk --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
if ($LASTEXITCODE -ne 0) { throw "flutter build a échoué (code $LASTEXITCODE)." }

$apk = Join-Path $racine 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) { throw "APK introuvable : $apk" }

# ─── Vérification de l'URL RÉELLEMENT embarquée ──────────────────────────
# Un `--dart-define` mal orthographié ne produit aucune erreur : il est
# simplement ignoré. La seule preuve est le binaire lui-même.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($apk)
try {
    $entree = $zip.Entries | Where-Object { $_.FullName -eq 'lib/arm64-v8a/libapp.so' }
    if (-not $entree) { throw 'lib/arm64-v8a/libapp.so absent de l''APK.' }

    $flux = $entree.Open()
    $memoire = New-Object System.IO.MemoryStream
    $flux.CopyTo($memoire)
    $flux.Dispose()
    $texte = [System.Text.Encoding]::ASCII.GetString($memoire.ToArray())
    $memoire.Dispose()
}
finally { $zip.Dispose() }

$attendu = $ApiBaseUrl.TrimEnd('/')
if ($texte -notlike "*$attendu*") {
    throw "L'URL $attendu n'apparaît PAS dans libapp.so : le --dart-define n'a pas pris."
}
# On cherche le domaine backend AVEC son schéma, et non le nom d'hôte seul :
# depuis le garde-fou d'`app_constants.dart`, ce nom d'hôte figure légitimement
# dans le binaire — c'est la clé de la liste de refus. Seule une URL complète
# trahit un `--dart-define` pointé sur le mauvais service.
foreach ($schema in @('https', 'http')) {
    if ($texte -like "*${schema}://genucapplication-production.up.railway.app*") {
        throw 'Le binaire est bâti sur le domaine backend (429 permanent). Build à jeter.'
    }
}
if ($texte -like '*10.0.2.2*') {
    throw 'Le binaire contient 10.0.2.2 (adresse d''émulateur) : ce n''est pas un vrai build release.'
}

# ─── Le domaine répond-il ? ──────────────────────────────────────────────
try {
    $reponse = Invoke-WebRequest -Uri "$attendu/api/universites/public" -Method Get -TimeoutSec 30 -SkipHttpErrorCheck
    Write-Host "→ $attendu/api/universites/public → HTTP $($reponse.StatusCode)" -ForegroundColor Cyan
    if ($reponse.StatusCode -ne 200) {
        Write-Warning "Le domaine livré ne répond pas 200. Un 429 ici = edge Railway, pas le limiteur applicatif."
    }
}
catch { Write-Warning "Domaine injoignable depuis ce poste : $($_.Exception.Message)" }

$empreinte = (Get-FileHash -Path $apk -Algorithm SHA1).Hash.ToLower()
$taille = [math]::Round((Get-Item $apk).Length / 1MB, 1)

Write-Host ''
Write-Host 'APK release prêt' -ForegroundColor Green
Write-Host "  fichier : $apk"
Write-Host "  taille  : $taille Mo"
Write-Host "  sha1    : $empreinte"
Write-Host "  API     : $attendu  (vérifié dans libapp.so)"
