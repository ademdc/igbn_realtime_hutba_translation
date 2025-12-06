# Quick Start Guide

Get the Bosnian → German translation app running in 5 minutes!

## Setup

```bash
# 1. Install dependencies
bundle install
npm install

# 2. Add your Soniox API key to .env
echo "SONIOX_API_KEY=your_key_here" > .env

# 3. Setup database
rails db:create db:migrate

# 4. Build JavaScript
npm run build

# 5. Start the server
bin/dev
```

## Usage

1. **Speaker**: Open `http://localhost:3000` and click "Start Recording"
2. **Listeners**: Open `http://localhost:3000/german` in other tabs/devices
3. **Speak**: Talk in Bosnian, see German translations appear for listeners!

## Files Structure

```
app/
├── channels/
│   └── translation_channel.rb        # Action Cable channel
├── controllers/
│   ├── speaker_controller.rb         # Speaker page
│   └── listener_controller.rb        # Listener page
├── services/
│   └── soniox_proxy_service.rb       # Soniox WebSocket proxy
├── javascript/
│   ├── application.js                # JS entry point
│   ├── channels/
│   │   ├── consumer.js               # Action Cable consumer
│   │   └── translation_channel.js    # Listener subscription
│   └── controllers/
│       └── speaker_controller.js     # Microphone recording
└── views/
    ├── speaker/
    │   └── index.html.erb            # Speaker UI
    └── listener/
        └── german.html.erb           # Listener UI
```

## How It Works

```
[Microphone] → [Browser Audio API] → [Action Cable]
    → [Rails Backend] → [Soniox WebSocket]
    → [German Translation] → [Action Cable Broadcast]
    → [All Listeners]
```

## Next Steps

- Customize the UI in `app/assets/stylesheets/application.css`
- Add more language pairs in `SonioxProxyService`
- Deploy to production with SSL for microphone access
