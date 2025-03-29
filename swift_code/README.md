# Nexus iOS App

A Swift/SwiftUI iOS application that connects to the Nexus database through a REST API.

## Project Structure

The project contains only essential files:

- **NexusApp.swift** - Entry point for the SwiftUI application
- **ContentView.swift** - Main UI components and user interface
- **NetworkManager.swift** - Data models and API communication
- **Info.plist** - App configuration and security settings
- **Assets.xcassets/** - Required for app icons

## How to Set Up

1. Open Xcode
2. Select "Open a project or file"
3. Navigate to the NexusApp folder and select it

## Backend Connection

This app connects to a Python Flask API that interfaces with the PostgreSQL database. The API needs to be running at `http://localhost:5000` for the app to function.

## How to Run

1. Start the backend API:
   ```
   python api.py
   ```

2. Run the app in Xcode using the play button

## Features

- View all users in the Nexus database
- Search for users by name, location, or other attributes
- View detailed user profiles including contact information
- See user connections and relationship descriptions
