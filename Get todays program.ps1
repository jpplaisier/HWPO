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
$gettoken = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $bodyJson

# Check if the response is valid
if (-not $gettoken) {
    Write-Error "Failed to fetch data from the API."
    return
}

# Define the API URL for the GET request
$todayDate = (Get-Date).ToString("yyyy-MM-dd")
$apiUrl = "https://app.hwpo-training.com/mobile/api/v3/athlete/schedules/$todayDate/plans/3216"

# Set up the HTTP headers with the Bearer token
$headers = @{
    "Authorization" = "Bearer $($gettoken.access_token)"
    "user-agent" = "HWPOClient/1.3.19 (hwpo-training-app; build:211732; iOS 15.8.2) Alamofire/5.4.1"
}

# Make the GET request to retrieve the HWPO schedule data
$getschedule = Invoke-RestMethod -Uri $apiUrl -Method GET -Headers $headers

# Check if the response is valid
if (-not $getschedule) {
    Write-Error "Failed to fetch program data from the API."
    return
}

# Extract the schedule date and convert to a readable format
$scheduleDate = [datetime]::UnixEpoch.AddSeconds($getschedule.schedule.date).ToString("dd-MM-yyyy")

# Prepare sections (warmup, strength, metcon, accessory) for HTML.
$sectionsHtml = ""
$addedSections = @()  # Array to track added section titles to prevent duplicates (some sections are returned twice by the API)

# Loop through the sections
foreach ($section in $getschedule.schedule.sections) {
    # Skip "pre_wod" and "post_wod" sections
    if ($section.kind -eq "pre_wod" -or $section.kind -eq "post_wod") {
        continue
    }

    # Check for duplicates based on title or kind
    if ($addedSections -contains $section.title -or $addedSections -contains $section.kind) {
        continue
    }

    # Mark section as added
    $addedSections += $section.title

    $sectionTitle = if ($section.title) { $section.title } else { "Section $($section.kind)" }
    $sectionDescription = if ($section.description) { $section.description } else { "No description available." }

    # Handle the DAILY VIDEO section
    if ($section.kind -eq "tip") {
        $youtubeUrl = $section.attachment_for_tip.src
        $sectionDescription += "<br/><a href='$youtubeUrl' target='_blank'>Watch Daily Video</a><br/>"
    }

    # Append section to HTML (retaining any HTML formatting)
    $sectionsHtml += "<div class='section'><h2>$sectionTitle</h2><div class='description'>$sectionDescription</div></div>"
}

# Combine all parts into a full HTML document
$htmlContent = @"
<html>
<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600&display=swap" rel="stylesheet">
    <title>Training Schedule</title>
    <style>
        body {
            font-family: 'Poppins', sans-serif; /* Use Poppins font */
            margin: 0;
            padding: 20px;
            background-color: #000; /* Black background */
            color: #fff; /* White font */
        }
        header {
            background-color: #222; /* Darker header */
            color: #fff;
            text-align: center;
            padding: 20px 0;
        }
        header img {
            max-width: 200px; /* Set the max width of the logo */
            margin: 0 auto; /* Center the logo */
            display: block; /* Center it horizontally */
        }
        h1 {
            margin-top: 10px; /* Add margin above the h1 */
            font-size: 1.8em; /* Increase font size for better visibility */
        }
        h2 {
            color: #ccc; /* Lighter heading color for contrast */
            margin-top: 20px;
        }
        .section {
            background: #333; /* Dark section background */
            color: #fff; /* White text for sections */
            margin: 10px 0;
            padding: 15px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.5);
        }
        .description {
            margin-top: 10px;
        }
        img {
            display: block;
            margin: 10px 0;
        }
        footer {
            text-align: center;
            padding: 20px 0;
            background-color: #222;
            color: #fff;
            width: 100%;
            position: relative;
            bottom: 0;
        }
    </style>
</head>
<body>
    <header>
        <img src='https://cdn.prod.website-files.com/61c2f086d385db179866da52/61c2ff8084dad62e03fa7111_HWPO-Training-Logo-White.svg' alt='HWPO Logo'>
        <h1>$scheduleDate</h1>
    </header>
    <main>
        $sectionsHtml
    </main>
    <footer>
        <p>&copy; 2024 Open Gym Crew</p>
    </footer>
</body>
</html>
"@

# Save the HTML to a file
Set-Content -Path "index.html" -Value $htmlContent

# Ensure that the output directory exists (e.g., _data folder)
$outputPath = Join-Path $workspace "_data"
if (-Not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Force -Path $outputPath
}