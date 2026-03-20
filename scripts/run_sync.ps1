$ProjectRoot = "/Users/carlos/Development/Leetcode Auto Answer Uploader"
Set-Location $ProjectRoot

if (Test-Path ".env") {
  Get-Content ".env" | ForEach-Object {
    if ($_ -and -not $_.StartsWith("#") -and $_.Contains("=")) {
      $parts = $_.Split("=", 2)
      [System.Environment]::SetEnvironmentVariable($parts[0], $parts[1])
    }
  }
}

mix run -e "LeetCodeSync.CLI.main(System.argv())" -- @Args
