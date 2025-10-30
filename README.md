## Personal Book Tracker (Backend)

Beginner-friendly Ruby/Sinatra JSON API to track books, authors, tags, reviews, and reading sessions.

### Stack
- Sinatra
- ActiveRecord + SQLite
- RSpec + rack-test

### Quick start

```bash
bundle install
ruby app.rb # http://localhost:4567
```

The app auto-migrates on boot. For explicit control:

```bash
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake db:seed
```

### Run tests

```bash
bundle exec rspec
```

### API Endpoints
- POST `/users`
- POST `/authors`
- POST `/books`
- GET `/books`
- GET `/books/:id`
- PATCH `/books/:id`
- DELETE `/books/:id`
- POST `/books/:id/tags`
- POST `/books/:id/reviews`
- POST `/books/:id/reading_sessions`
- GET `/stats`

All responses are JSON.

### Environment
Databases are created under `db/` per environment (`development.sqlite3`, `test.sqlite3`).

### Notes
- Demo only; authentication is not implemented.
- Payloads should be JSON; invalid JSON returns 400.


