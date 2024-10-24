param (
    [string]$BodyJson # This parameters contains the API authentication details
)

# Get the GitHub Actions workspace environment variable
$workspace = $env:GITHUB_WORKSPACE

# Define the API URL for the authentication
$apiUrl = "https://app.hwpo-training.com/mobile/api/v3/users/sign_in"

# Set up the HTTP headers
$headers = @{
    "user-agent" = "HWPOClient/1.3.19 (hwpo-training-app; build:211732; iOS 15.8.2) Alamofire/5.4.1"
    "Content-Type" = "application/json"
}

# Make the POST request to retrieve the Bearer token
$response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $bodyJson

# Check if the response is valid
if (-not $response) {
    Write-Error "Failed to fetch data from the API."
    return
}

# Define the API URL for the GET request
$todayDate = (Get-Date).ToString("yyyy-MM-dd")
$apiUrl = "https://app.hwpo-training.com/mobile/api/v3/athlete/schedules/$todayDate/plans/3216"

# Set up the HTTP headers with the Bearer token
$headers = @{
    "Authorization" = "Bearer $($response.access_token)"
    "user-agent" = "HWPOClient/1.3.19 (hwpo-training-app; build:211732; iOS 15.8.2) Alamofire/5.4.1"
}

# Make the GET request to retrieve the schedule data
$scheduleResponse = Invoke-RestMethod -Uri $apiUrl -Method GET -Headers $headers

# Check if the response is valid
if (-not $scheduleResponse) {
    Write-Error "Failed to fetch schedule data from the API."
    return
}

# Create output directory to store files in for troubleshooting purposes
New-Item -ItemType directory -Path .\output -Force

# Initialize an object to store the combined data
$combinedData = [PSCustomObject]@{
    schedule = $scheduleResponse.schedule
    sections = @()  # Array to store section details
}

# Loop through each section in the schedule and retrieve detailed data
foreach ($section in $scheduleResponse.schedule.sections) {
    # Skip "pre_wod" and "post_wod" sections
    if ($section.kind -eq "pre_wod" -or $section.kind -eq "post_wod") {
        continue
    }

    $sectionId = $section.id
    $scheduleId = $scheduleResponse.schedule.id
    $sectionname = $section.title
    $detailApiUrl = "https://app.hwpo-training.com/mobile/api/v3/schedules/$scheduleId/sections/$sectionId"

    #Write-Host "sectionId = $sectionId"
    #Write-Host "scheduleId = $scheduleId"
    #Write-Host "sectionname = $sectionname"
    #Write-Host "detailApiUrl = $detailApiUrl"
    
    # Make the GET request for section details
    $sectionDetailResponse = Invoke-RestMethod -Uri $detailApiUrl -Method GET -Headers $headers

    # Check if the response is valid
    if (-not $sectionDetailResponse) {
        Write-Error "Failed to fetch section data from the API."
        return
    }

    # Add the section details to the combined data
    $combinedData.sections += [PSCustomObject]@{
        sectionName = $sectionname
        sectionDetails = $sectionDetailResponse
    }
}

# Convert the combined data to JSON format
$combinedData = $combinedData | ConvertTo-Json -Depth 10

# Ensure that the output directory exists (e.g., _data folder)
$outputPath = Join-Path $workspace "Pages/_data"
if (-Not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Force -Path $outputPath
}

# Export the combined data to JSON (Make sure to modify the path as needed)
$combinedData | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $outputPath "program.json") -Encoding utf8

Write-Host "Training data saved to program.json at $outputPath"