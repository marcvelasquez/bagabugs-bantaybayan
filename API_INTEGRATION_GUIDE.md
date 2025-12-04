# Connecting Flutter App to FastAPI Backend

## Overview
This guide explains how to connect your BantayBayan Flutter application to the FastAPI backend server.

## Architecture

```
Flutter App (Client) <---> HTTP Requests <---> FastAPI Server (Backend)
```

## Setup Instructions

### 1. Start the FastAPI Server

Open a new PowerShell terminal and navigate to the server directory:

```powershell
cd server

# Create virtual environment (first time only)
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Install dependencies (first time only)
pip install -r requirements.txt

# Copy environment file (first time only)
cp .env.example .env

# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The server will start at: `http://localhost:8000`

**API Documentation:** http://localhost:8000/docs

### 2. Configure Flutter App

#### For Emulator Testing (Default)
The default configuration in `lib/core/api_config.dart` is already set:

```dart
static const String baseUrl = 'http://localhost:8000/api';
```

This works for:
- Android Emulator (uses 10.0.2.2 internally mapped to localhost)
- iOS Simulator
- Desktop (Windows/Mac/Linux)

#### For Physical Device Testing
You need to use your computer's IP address:

1. Find your IP address:
```powershell
ipconfig
```
Look for "IPv4 Address" (e.g., 192.168.1.5)

2. Update `lib/core/api_config.dart`:
```dart
static const String baseUrl = 'http://192.168.1.5:8000/api';
```

3. Make sure your phone and computer are on the same Wi-Fi network.

## Files Created

### 1. **API Configuration** (`lib/core/api_config.dart`)
- Defines the base URL and all API endpoints
- Easy to change for different environments

### 2. **API Models** (`lib/models/api_models.dart`)
- `ReportModel` - Incident report data
- `IncidentModel` - Aggregated incident data
- `ReportStats` - Statistics for the dashboard
- `UserModel` - User authentication data
- `IncidentType` - Enum for incident types (info/warning/critical)

### 3. **API Service** (`lib/services/api_service.dart`)
- `createReport()` - Submit a new incident report
- `getReportStats()` - Fetch report statistics
- `getReports()` - Get all reports with filters
- `getIncidents()` - Get all incidents
- `login()` / `register()` - User authentication

### 4. **Updated Situation Screen** (`lib/screens/situation_screen.dart`)
- Fetches real-time statistics from the API
- Submits reports to the backend
- Auto-refreshes stats after submission
- Error handling with user feedback

## How It Works

### Example: Submitting a Report

1. **User Action**: User pins a location and clicks "Report Incident"
2. **Flutter App**: Creates a `ReportModel` with location and type
3. **API Call**: `ApiService.createReport()` sends POST request
4. **FastAPI**: Receives data, validates, stores in database
5. **Response**: Returns saved report with ID and timestamp
6. **Flutter App**: Shows success message and refreshes stats

### Example: Loading Statistics

1. **App Loads**: `_loadReportStats()` is called in `initState()`
2. **API Call**: `ApiService.getReportStats()` sends GET request
3. **FastAPI**: Queries database for counts by type
4. **Response**: Returns `{info_count: 5, critical_count: 25, warning_count: 8}`
5. **Flutter App**: Updates UI with real data

## API Endpoints Used

### Reports
- `POST /api/reports/` - Create new report
- `GET /api/reports/` - Get all reports
- `GET /api/reports/stats` - Get statistics
- `GET /api/reports/{id}` - Get specific report
- `PUT /api/reports/{id}` - Update report
- `DELETE /api/reports/{id}` - Delete report

### Incidents
- `POST /api/incidents/` - Create incident
- `GET /api/incidents/` - Get all incidents
- `GET /api/incidents/active` - Get active incidents
- `GET /api/incidents/{id}` - Get specific incident

### Authentication
- `POST /api/auth/register` - Register user
- `POST /api/auth/login` - Login user

## Testing the Connection

### 1. Test the API Server

Open http://localhost:8000/docs in your browser and test endpoints directly.

### 2. Test from Flutter

Run your Flutter app:
```powershell
flutter run
```

Watch the console for:
- ✅ Successful API calls: Status 200
- ❌ Errors: Connection refused, timeouts, etc.

### 3. Common Issues

**"Connection refused" or "Failed to connect"**
- Make sure the FastAPI server is running
- Check the IP address in `api_config.dart`
- For Android Emulator, try `http://10.0.2.2:8000/api`

**"CORS error"**
- The server already has CORS configured for localhost
- Add your device IP to `ALLOWED_ORIGINS` in `server/.env`

**"SSL/Certificate error"**
- Use `http://` not `https://` for local development

## Data Flow Example

### Creating a Report

```dart
// 1. User pins location (14.5995, 120.9842)
// 2. User selects "Critical" and adds description
// 3. Flutter creates model:

final report = ReportModel(
  incidentType: IncidentType.critical,
  latitude: 14.5995,
  longitude: 120.9842,
  description: "Flooding on main street",
);

// 4. Send to API:
final savedReport = await ApiService.createReport(report);

// 5. Server stores in database and returns:
{
  "id": 1,
  "user_id": 1,
  "incident_type": "critical",
  "latitude": 14.5995,
  "longitude": 120.9842,
  "description": "Flooding on main street",
  "created_at": "2025-12-04T10:30:00",
  "is_verified": false
}

// 6. Flutter shows success and refreshes stats
```

## Next Steps

### Authentication (Optional)
Currently, reports are submitted without authentication. To add user login:

1. Create a login screen
2. Call `ApiService.login()` or `ApiService.register()`
3. Store the token: `ApiService.setAuthToken(token)`
4. All subsequent API calls will include the auth token

### Real-time Updates (Optional)
For live updates when new reports come in:

1. Add WebSocket support to FastAPI
2. Use `web_socket_channel` package in Flutter
3. Listen for new report notifications

### Production Deployment
When deploying to production:

1. Update `baseUrl` to your production API URL
2. Use environment variables for different builds
3. Enable HTTPS/SSL
4. Update CORS settings on the server

## File Structure

```
lib/
├── core/
│   └── api_config.dart          # API URLs and configuration
├── models/
│   └── api_models.dart          # Data models matching API
├── services/
│   └── api_service.dart         # API calls and HTTP logic
└── screens/
    └── situation_screen.dart    # UI using API data

server/
├── app/
│   ├── api/                     # API endpoints
│   ├── models/                  # Database models
│   └── main.py                  # FastAPI app
└── requirements.txt             # Python dependencies
```

## Support

For API documentation and testing:
- Interactive Docs: http://localhost:8000/docs
- Alternative Docs: http://localhost:8000/redoc
- Server Status: http://localhost:8000/health

## Summary

✅ **Server Running**: FastAPI backend on port 8000
✅ **Flutter Connected**: Using `http` package and `ApiService`
✅ **Models Created**: Matching request/response schemas
✅ **UI Updated**: Reports screen fetches real data
✅ **Submissions Work**: Reports saved to database
✅ **Error Handling**: User-friendly error messages

Your Flutter app is now fully connected to the FastAPI backend! 🎉
