# Weekly Training Schedule Automation

This PowerShell script retrieves a weekly training schedule from the HWPO Training API, formats it into an HTML file, and highlights the current day's schedule by default. The resulting HTML file includes day navigation, as well as converters for weight, length, and percentages.

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)

---

## Features
- **Weekly Schedule Retrieval**: Fetches data for each day of the week from the HWPO Training API, combining it into a single HTML file.
- **Day Selector**: Allows navigation between days of the week.
- **Current Day Highlighting**: Automatically highlights today’s date.
- **Built-in Converters**:
  - Weight Converter (lbs to kg)
  - Length Converter (feet to meters)
  - Percentage Calculator

## Requirements
- A valid API authentication JSON object (containing email and password for HWPO Training API)