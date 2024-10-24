param (
    [string]$BodyJson # This parameters contains the API authentication details
)

# Get the GitHub Actions workspace environment variable
$workspace = $env:GITHUB_WORKSPACE

# Define folder path
$folderPath = ".\output"

# Check if the folder exists, if not, create it
if (-not (Test-Path -Path $folderPath)) {
    New-Item -ItemType directory -Path $folderPath -Force
}

# Remove all JSON files in the folder before proceeding
Remove-Item -Path "$folderPath\*.json" -Force

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

# Make the GET request to retrieve the HWPO schedule data
$scheduleResponse = Invoke-RestMethod -Uri $apiUrl -Method GET -Headers $headers

# Check if the response is valid
if (-not $scheduleResponse) {
    Write-Error "Failed to fetch schedule data from the API."
    return
}

# Save the JSON file to the output folder
$scheduleResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath "$folderPath\fullSchedule.json"

# Loop through each section in the schedule and retrieve detailed program data (workout example videos)
foreach ($section in $scheduleResponse.schedule.sections) {
    # Skip "pre_wod" and "post_wod" sections
    if ($section.kind -eq "pre_wod" -or $section.kind -eq "post_wod") {
        continue
    }

    $sectionId = $section.id
    $scheduleId = $scheduleResponse.schedule.id
    $sectionname = $section.title
    $detailApiUrl = "https://app.hwpo-training.com/mobile/api/v3/schedules/$scheduleId/sections/$sectionId"
    $filename = "$sectionname.json"

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

    $filePath = ".\output\$filename"
    $sectionDetailResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath
}

# Get all JSON files from the folder
$jsonFiles = Get-ChildItem -Path $folderPath -Filter *.json

# Initialize a hashtable to store the loaded JSON data
$jsonData = @{}

# Loop through each JSON file and load the data
foreach ($file in $jsonFiles) {
    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $jsonData[$fileNameWithoutExtension] = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json
}

# Ensure the main schedule is loaded correctly
if ($jsonData.ContainsKey('fullSchedule')) {
    $scheduleResponse = $jsonData['fullSchedule']  # Main schedule
} else {
    Write-Host "Error: fullSchedule not found!"
    exit
}

# Print loaded keys for debugging
Write-Host "Loaded JSON files:" $jsonData.Keys

# Start building the HTML content
$html = @"
<html>
<head>
    <style>
        body { font-family: 'Proxima Nova'; font-size: 14px; color: #0D0D0D; line-height: 24px; letter-spacing: 0.38px; }
        h1 { color: #db2b44; }
        .section { margin-bottom: 20px; }
        .section-title { font-weight: bold; }
    </style>
</head>
<body>
    <h1>Training Schedule for $($scheduleResponse.schedule.plan.title)</h1>
"@

# Loop through sections in the main schedule
foreach ($section in $scheduleResponse.schedule.sections) {
    $html += "<div class='section'>"
    
    # Add title and description based on section type
    if ($section.title) {
        $html += "<h2 class='section-title'>$($section.title)</h2>"
    }

    # Match section dynamically based on earlier gathered data
    foreach ($key in $jsonData.Keys) {
        $sectionData = $jsonData[$key]

        # If the current section's ID matches one from the JSON data
        if ($section.id -eq $sectionData.id) {
            $html += "<p>$($sectionData.description)</p>"

            # If the section has attachments (like videos), display them
            if ($sectionData.attachments) {
                foreach ($attachment in $sectionData.attachments) {
                    $html += "<p><a href='$($attachment.src)'>$($attachment.title)</a></p>"
                }
            }
        }
    }

    $html += "</div>"
}

# Finish the HTML
$html += "</body></html>"

# Save the HTML to a file
Set-Content -Path "index.html" -Value $html

# Ensure that the output directory exists (e.g., _data folder)
$outputPath = Join-Path $workspace "_data"
if (-Not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Force -Path $outputPath
}