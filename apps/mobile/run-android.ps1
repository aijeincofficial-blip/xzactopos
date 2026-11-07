# Runs the Flutter app on the Android emulator against the local Supabase stack.
# The emulator reaches this PC at 10.0.2.2. The anon key is read from the React client's gitignored .env.local.
# Start the emulator first (Android Studio > Device Manager, or: emulator -avd Pixel_4_API_33).
$envFile = Join-Path $PSScriptRoot '..\client\.env.local'
$vars = @{}
Get-Content $envFile | ForEach-Object { if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$') { $vars[$Matches[1]] = $Matches[2].Trim('"') } }
$key = $vars['VITE_SUPABASE_ANON_KEY']
if (-not $key) { throw 'VITE_SUPABASE_ANON_KEY not found in apps/client/.env.local' }
Set-Location $PSScriptRoot
flutter run -d emulator --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=$key @args
