param (
    [string]$BodyJson # Contains the API authentication details
)

# Get the GitHub Actions workspace environment variable
$workspace = $env:GITHUB_WORKSPACE

# Define the API URL for authentication
$apiUrl = "https://app.hwpo-training.com/mobile/api/v3/users/sign_in"

# Set up the HTTP headers
$headers = @{
    "user-agent"   = "HWPOClient/1.3.19 (hwpo-training-app; build:211732; iOS 18.1.1) Alamofire/5.4.1"
    "Content-Type" = "application/json"
}

# Make the POST request to retrieve the Bearer token
$gettoken = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $BodyJson

# Check if the response is valid
if (-not $gettoken) {
    Write-Error "Failed to fetch data from the API."
    return
}

# Initialize a variable to hold HTML for the entire week's schedule
$weekHtml = ""

# Loop through each day of the week (0=Sunday, 1=Monday, ..., 6=Saturday) (Start with 1 because Sunday is not needed, restday)
for ($i = 1; $i -lt 7; $i++) {
    # Calculate the date for each day of the week
    $date = (Get-Date).AddDays($i - (Get-Date).DayOfWeek.value__).ToString("yyyy-MM-dd")
    $apiUrl = "https://app.hwpo-training.com/mobile/api/v3/athlete/schedules/$date/plans/3216"
    
    # Update headers with Bearer token
    $headers["Authorization"] = "Bearer $($gettoken.access_token)"
    
    # Get schedule
    $getschedule = Invoke-RestMethod -Uri $apiUrl -Method GET -Headers $headers
    if (-not $getschedule) { continue }
    
    #######
    #$getschedule | ConvertTo-Json -Depth 10 | Set-Content -Path ".\$date.json"
    #######

    # Format the date
    $scheduleDate = [datetime]::UnixEpoch.AddSeconds($getschedule.schedule.date).ToString("dd-MM-yyyy")
    
    # Prepare sections for each day
    $dayHtml = "<div class='day' id='day-$i' style='display:none;'>"
    $dayHtml += "<h2>$scheduleDate</h2>"

    foreach ($section in $getschedule.schedule.sections) {
        # Skip "pre_wod" and "post_wod" sections and non-matching plan_option_id (2905 = 60, 2906 = FLAGSHIP 2.0)
        if (($section.kind -eq "pre_wod" -or $section.kind -eq "post_wod") -or $section.plan_option_id -eq 2905) { continue }
        
        # Retrieve additional section details
        $sectionId = $section.id
        $scheduleId = $getschedule.schedule.id
        $sectionDetailsUrl = "https://app.hwpo-training.com/mobile/api/v3/schedules/$scheduleId/sections/$sectionId"
        
        # Fetch the section details
        $sectionDetails = Invoke-RestMethod -Uri $sectionDetailsUrl -Method GET -Headers $headers
        
        ####### only for debugging
        #$sectionDetails | ConvertTo-Json -Depth 10 | Set-Content -Path ".\$date-details.json"
        #######

        # Extract section title, description, and available videos
        $sectionTitle = if ($section.title) { $section.title } else { "Section $($section.kind)" }
        $sectionDescription = if ($section.description) { $section.description } else { "No description available." }
    
        # Add section content to HTML
        $dayHtml += "<div class='section'><h2>$sectionTitle</h2><div class='description'>$sectionDescription</div>"
    
        # Loop through attachments to include videos with titles
        foreach ($attachment in $sectionDetails.attachments) {
            if (($attachment.type -eq "video" -or $attachment.type -eq "youtube") -and $attachment.src) {
                $videoUrl = $attachment.src
                $videoTitle = $attachment.title
        
                $dayHtml += "<div class='section-content' style='text-align: left; margin-top: 10px;'>"
                $dayHtml += "<h3>$videoTitle</h3>"
        
                # Use iframe for YouTube and video tag for CDN
                if ($attachment.type -eq "youtube") {
                    # Extract the video ID and construct the embed URL
                    if ($videoUrl -match "youtu\.be\/([a-zA-Z0-9_-]+)") {
                        $videoId = $matches[1]
                        $embedUrl = "https://www.youtube.com/embed/$videoId"
                    }
                    elseif ($videoUrl -match "youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)") {
                        $videoId = $matches[1]
                        $embedUrl = "https://www.youtube.com/embed/$videoId"
                    }
                    else {
                        $embedUrl = $videoUrl # Fallback in case of an unexpected format
                    }
                    
                    # Add iframe for YouTube video
                    $dayHtml += "<iframe src='$embedUrl' style='max-width: 100%; height: auto; margin-top: 10px;' frameborder='0' allow='accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture' allowfullscreen loading='lazy'></iframe>"
                }
                else {
                    # Use video tag for CDN-hosted videos
                    $dayHtml += "<video controls preload='none' muted style='max-width: 100%; height: auto; margin-top: 5px;' loading='lazy'>"
                    $dayHtml += "<source src='$videoUrl' type='video/mp4'>"
                    $dayHtml += "Your browser does not support the video tag."
                    $dayHtml += "</video>"
                }
        
                $dayHtml += "</div>"
            }
        }
        
        $dayHtml += "</div>"  # Close section div
    }
    $dayHtml += "</div>"  # Close day div
    $weekHtml += $dayHtml
}

# Combine all days into the final HTML
$htmlContent = @"
<html>
<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;600&display=swap" rel="stylesheet">
    <title>Weekly Training Schedule</title>
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
            border: 1px solid #ffd700; /* Golden border */            
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
            text-transform: uppercase; /* Make titles uppercase */
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
        input {
            padding: 5px;
            width: 100%;
            border-radius: 5px;
            margin: 5px 0;
        }
        .day-selector button {
            margin: 5px;
            padding: 10px;
            background-color: #555;
            color: #fff;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
        .day-selector button:hover {
            background-color: #888;
        }
        .highlight {
            background-color: #ffa500;
            color: #000;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <header>
        <img src='https://cdn.prod.website-files.com/61c2f086d385db179866da52/61c2ff8084dad62e03fa7111_HWPO-Training-Logo-White.svg' alt='HWPO Logo'>
        <img src='https://img.freepik.com/free-photo/sexy-santa-man-isolated-white-background_1303-12802.jpg' alt='BiSanta'>
        <h1>🎄 Weekly Training Schedule 🎄</h1>
        <div class="day-selector">
            <button onclick="showDay(1)" id="button-1">Monday</button>
            <button onclick="showDay(2)" id="button-2">Tuesday</button>
            <button onclick="showDay(3)" id="button-3">Wednesday</button>
            <button onclick="showDay(4)" id="button-4">Thursday</button>
            <button onclick="showDay(5)" id="button-5">Friday</button>
            <button onclick="showDay(6)" id="button-6">Saturday</button>
        </div>
    </header>
    <main>
        $weekHtml

        <!-- Weight Converter Section -->
        <div class="section">
            <h2>Weight Converter</h2>
            <p>Type a weight in pounds to convert it to kilograms:</p>
            <input id="pounds" type="number" placeholder="Enter weight in lbs" oninput="convertWeight()">
            <p id="kilograms"></p>
        </div>

        <!-- Length Converter Section -->
        <div class="section">
            <h2>Length Converter</h2>
            <p>Type a length in feet to convert it to meters:</p>
            <input id="feet" type="number" placeholder="Enter length in feet" oninput="convertLength()">
            <p id="meters"></p>
        </div>

        <!-- Percentage Calculator Section -->
        <div class="section">
            <h2>Percentage Calculator</h2>
            <p>Enter the values to calculate a percentage:</p>
            <input id="baseValue" type="number" placeholder="Enter the base value">
            <input id="percentageValue" type="number" placeholder="Enter the percentage" oninput="calculatePercentage()">
            <p id="percentageResult"></p>
        </div>
    </main>
    <footer>
        <p>&copy; 2025 Open Gym Crew</p>
    </footer>

    <script>
        // Show the selected day's content
        function showDay(dayIndex) {
            document.querySelectorAll('.day').forEach(day => day.style.display = 'none');
            document.getElementById('day-' + dayIndex).style.display = 'block';

            // Highlight the selected day button
            document.querySelectorAll('.day-selector button').forEach(btn => btn.classList.remove('highlight'));
            document.getElementById('button-' + dayIndex).classList.add('highlight');
        }
        
        // Highlight today's button and show today's content by default
        const todayIndex = new Date().getDay();
        document.getElementById('button-' + todayIndex).classList.add('highlight');
        showDay(todayIndex);

        function convertWeight() {
            let lbs = document.getElementById("pounds").value;
            let kg = lbs / 2.20462;
            document.getElementById("kilograms").innerHTML = lbs ? lbs + " lbs is equal to " + kg.toFixed(2) + " kg." : "";
        }

        function convertLength() {
            let feet = document.getElementById("feet").value;
            let meters = feet * 0.3048;
            document.getElementById("meters").innerHTML = feet ? feet + " ft is equal to " + meters.toFixed(2) + " m." : "";
        }

        function calculatePercentage() {
            let baseValue = document.getElementById("baseValue").value;
            let percentageValue = document.getElementById("percentageValue").value;
            let result = (baseValue * percentageValue) / 100;
            document.getElementById("percentageResult").innerHTML = baseValue && percentageValue ? percentageValue + "% of " + baseValue + " is " + result.toFixed(2) : "";
        }
    </script>
</body>
</html>
"@

# Save the HTML to a file
Set-Content -Path "index.html" -Value $htmlContent

# Ensure the output directory exists
$outputPath = Join-Path $workspace "_data"
if (-Not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Force -Path $outputPath
}