$ProjectRoot = "C:\LeetCodeSync"
$ScriptPath = Join-Path $ProjectRoot "scripts\run_sync.ps1"
$TaskName = "LeetCodeSync"

$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
$DailyTrigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
$LogonTrigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($DailyTrigger, $LogonTrigger) -Settings $Settings -Force
Write-Host "Installed scheduled task: $TaskName"
