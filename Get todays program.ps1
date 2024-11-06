param (
    [string]$BodyJson # Contains the API authentication details
)

# Get the GitHub Actions workspace environment variable
$workspace = $env:GITHUB_WORKSPACE

# Retrieve the pincode from Github Secrets
$pincode = process.env['SITE_PINCODE']

# Define the API URL for authentication
$apiUrl = "https://app.hwpo-training.com/mobile/api/v3/users/sign_in"

# Set up the HTTP headers
$headers = @{
    "user-agent" = "HWPOClient/1.3.19 (hwpo-training-app; build:211732; iOS 18.0.1) Alamofire/5.4.1"
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

# Loop through each day of the week (0=Sunday, 1=Monday, ..., 6=Saturday)
for ($i = 0; $i -lt 7; $i++) {
    # Calculate the date for each day of the week
    $date = (Get-Date).AddDays($i - (Get-Date).DayOfWeek.value__).ToString("yyyy-MM-dd")
    $apiUrl = "https://app.hwpo-training.com/mobile/api/v3/athlete/schedules/$date/plans/3216"
    
    # Update headers with Bearer token
    $headers["Authorization"] = "Bearer $($gettoken.access_token)"
    
    # Get schedule for the specific day
    $getschedule = Invoke-RestMethod -Uri $apiUrl -Method GET -Headers $headers
    if (-not $getschedule) { continue }
    
    # Format the date
    $scheduleDate = [datetime]::UnixEpoch.AddSeconds($getschedule.schedule.date).ToString("dd-MM-yyyy")
    
    # Prepare sections for each day
    $dayHtml = "<div class='day' id='day-$i' style='display:none;'>"
    $dayHtml += "<h1>$scheduleDate</h1>"

    # Track added sections to prevent duplicates
    $addedSections = @()  # Array to track added section titles and kinds

    foreach ($section in $getschedule.schedule.sections) {
        # Skip "pre_wod" and "post_wod" sections
        if ($section.kind -eq "pre_wod" -or $section.kind -eq "post_wod") { continue }

        # Check for duplicates based on title or kind
        if ($addedSections -contains $section.title -or $addedSections -contains $section.kind) {
            continue
        }

        # Mark section as added
        $addedSections += $section.title

        $sectionTitle = if ($section.title) { $section.title } else { "Section $($section.kind)" }
        $sectionDescription = if ($section.description) { $section.description } else { "No description available." }

        if ($section.kind -eq "tip") {
            $youtubeUrl = $section.attachment_for_tip.src
            $sectionDescription += "<br/><a href='$youtubeUrl' target='_blank'>Watch Daily Video</a><br/>"
        }

        $dayHtml += "<div class='section'><h2>$sectionTitle</h2><div class='description'>$sectionDescription</div></div>"
    }
    $dayHtml += "</div>"
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
        
        /* Pincode Authentication Overlay */
        #pincodeOverlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.8);
            color: white;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: 'Poppins', sans-serif;
            z-index: 9999;
        }

        #pincodeBox {
            text-align: center;
            padding: 20px;
            background-color: #333;
            border-radius: 10px;
        }

        #pincodeBox input {
            padding: 10px;
            border: none;
            border-radius: 5px;
            font-size: 1.2em;
            text-align: center;
            margin-top: 10px;
        }

        #pincodeBox button {
            margin-top: 10px;
            padding: 10px 20px;
            font-size: 1em;
            background-color: #ffa500;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <!-- Pincode Overlay -->
    <div id="pincodeOverlay">
        <div id="pincodeBox">
            <h2>Enter Access Code</h2>
            <input type="password" id="pincodeInput" placeholder="Enter pincode" maxlength="4">
            <button onclick="checkPincode()">Submit</button>
            <p id="errorMessage" style="color: red; display: none;">Incorrect pincode. Try again.</p>
        </div>
    </div>

    <header>
        <img src='https://cdn.prod.website-files.com/61c2f086d385db179866da52/61c2ff8084dad62e03fa7111_HWPO-Training-Logo-White.svg' alt='HWPO Logo'>
        <h1>Weekly Training Schedule</h1>
        <div class="day-selector">
            <button onclick="showDay(0)" id="button-0">Sunday</button>
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
        <p>&copy; 2024 Open Gym Crew</p>
    </footer>

    <script>
        // Pincode validation logic
        function checkPincode() {
            const pincode = document.getElementById('pincodeInput').value;
            if (pincode === $pincode) {
                document.getElementById('pincodeOverlay').style.display = 'none';
            } else {
                document.getElementById('errorMessage').style.display = 'block';
            }
        }

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
