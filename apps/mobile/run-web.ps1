# Runs the Flutter app in Chrome against the local Supabase stack.
# The anon key is read from the React client's gitignored .env.local; nothing secret is stored here.
$envFile = Join-Path $PSScriptRoot '..\client\.env.local'
$vars = @{}
Get-Content $envFile | ForEach-Object { if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$') { $vars[$Matches[1]] = $Matches[2].Trim('"') } }
$url = if ($vars['VITE_SUPABASE_URL']) { $vars['VITE_SUPABASE_URL'] } else { 'http://127.0.0.1:54321' }
$key = $vars['VITE_SUPABASE_ANON_KEY']
if (-not $key) { throw 'VITE_SUPABASE_ANON_KEY not found in apps/client/.env.local' }
Set-Location $PSScriptRoot
flutter run -d chrome --dart-define=SUPABASE_URL=$url --dart-define=SUPABASE_ANON_KEY=$key @args
