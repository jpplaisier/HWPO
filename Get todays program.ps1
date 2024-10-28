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
            font-family: 'Poppins', sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #000;
            color: #fff;
        }
        header, footer {
            background-color: #222;
            color: #fff;
            text-align: center;
            padding: 20px 0;
            border-radius: 15px;
        }
        header img {
            max-width: 200px;
            margin: 0 auto;
            display: block;
        }
        h1 {
            margin-top: 10px;
            font-size: 1.8em;
        }
        h2 {
            color: #ccc;
            margin-top: 20px;
        }
        .section {
            background: #333;
            color: #fff;
            margin: 10px 0;
            padding: 15px;
            border-radius: 15px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.5);
        }
        .description {
            margin-top: 10px;
        }
        a {
            color: #fff;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        img {
            display: block;
            margin: 10px 0;
        }
        footer {
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
        <!-- New Weight Converter Section -->
        <div class="section">
            <h2>Weight Converter</h2>
            <p>Type a weight in pounds to convert it to kilograms:</p>
            <input id="pounds" type="number" placeholder="Enter weight in lbs" oninput="convertWeight()" style="padding: 5px; width: 100%; border-radius: 5px;">
            <p id="kilograms"></p>
        </div>
    </main>
    <footer>
        <p>&copy; 2024 Open Gym Crew</p>
    </footer>

    <script>
        // JavaScript function to convert weight from lbs to kg
        function convertWeight() {
            let lbs = document.getElementById("pounds").value;
            let kg = lbs / 2.20462;
            document.getElementById("kilograms").innerHTML = lbs ? lbs + " lbs is equal to " + kg.toFixed(2) + " kg." : "";
        }
    </script>
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