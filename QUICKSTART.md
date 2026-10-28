# Quick Start

```bash
bundle install && npm install
bin/rails db:prepare db:seed
PORT=3020 bin/rails server -p 3020
```

Then open http://localhost:3020/de (marketing site) or http://demo.localhost:3020/login
(`owner@demo.test` / `password1234`). See [SETUP.md](SETUP.md) for everything else.
