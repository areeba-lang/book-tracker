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

### Configuration

Optional API key authentication can be enabled via environment variable:

```bash
export API_KEY=your_secret_key_here
ruby app.rb
```

When `API_KEY` is set, all mutating endpoints (POST, PATCH, DELETE) require the `X-API-Key` header:
```bash
curl -X POST http://localhost:4567/books \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your_secret_key_here" \
  -d '{"user_id":1,"title":"Dune","author_name":"Frank Herbert"}'
```

When `API_KEY` is not set, all endpoints work without authentication (backward compatible). Read-only endpoints (GET) are always public.

### Environment
Databases are created under `db/` per environment (`development.sqlite3`, `test.sqlite3`).

### Notes
- Payloads should be JSON; invalid JSON returns 400.
- API key authentication is optional and disabled by default.


