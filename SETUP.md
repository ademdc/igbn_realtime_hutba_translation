# IGBD Translations App - Setup Guide

This Rails application provides real-time Bosnian to German translation using Soniox API.

## Prerequisites

- Ruby 3.1.2
- PostgreSQL
- Node.js and npm (for JavaScript bundling)

## Installation Steps

### 1. Install Dependencies

```bash
# Install Ruby gems
bundle install

# Install JavaScript dependencies
npm install
```

### 2. Configure Environment Variables

Edit `.env` file and add your configuration:

```bash
# Soniox API Key (required)
SONIOX_API_KEY=your_actual_soniox_api_key_here

# Speaker PIN Protection (required)
# 6-digit PIN to access the speaker page
SPEAKER_PIN=123456
```

**Important:**
- Get your Soniox API key from [Soniox Console](https://soniox.com/console)
- Change the `SPEAKER_PIN` to your own secure 6-digit number
- The speaker page (/) is PIN-protected for security

### 3. Setup Database

```bash
# Create and migrate database
rails db:create
rails db:migrate
```

### 4. Build JavaScript

```bash
# Build JavaScript assets
npm run build
```

### 5. Start the Server

```bash
# Start Rails server
rails server
```

The app will be available at `http://localhost:3000`

## Usage

### Speaker Page (/)

1. Navigate to `http://localhost:3000`
2. Click "Start Recording"
3. Allow microphone access when prompted
4. Speak in Bosnian
5. Translations will be broadcast to all German listeners

### Listener Page (/german)

1. Navigate to `http://localhost:3000/german`
2. Wait for the speaker to start broadcasting
3. See real-time German translations appear

## How It Works

1. **Speaker captures audio** from microphone
2. **Audio is sent via Action Cable** to Rails backend
3. **Rails forwards audio to Soniox API** via WebSocket
4. **Soniox translates Bosnian → German** in real-time
5. **German translations broadcast** to all `/german` listeners via Action Cable

## Architecture

- **Frontend**: Rails views with Vanilla JavaScript
- **Real-time Communication**: Action Cable (WebSockets)
- **Translation API**: Soniox Real-Time Translation
- **Audio Processing**: Web Audio API

## Troubleshooting

### Microphone not working
- Ensure you've granted microphone permissions to your browser
- Check browser console for errors
- HTTPS is required for microphone access (localhost is exempt)

### Translations not appearing
- Verify your Soniox API key is correct in `.env`
- Check Rails logs for connection errors
- Ensure Action Cable is running (check browser console)

### Build errors
- Run `npm install` to ensure dependencies are installed
- Run `npm run build` to rebuild JavaScript

## Development

To watch for JavaScript changes during development:

```bash
npm run build -- --watch
```

## Production Deployment

1. Set `SONIOX_API_KEY` environment variable
2. Configure Redis for Action Cable
3. Precompile assets: `rails assets:precompile`
4. Set up SSL certificate (required for microphone access)
