require "spec_helper"

RSpec.describe "API Key Authentication", type: :request do
  let(:api_key) { "test_secret_key_123" }
  let(:wrong_key) { "wrong_key" }
  let!(:user) { User.create!(email: "auth@example.com", name: "Auth") }
  let!(:author) { Author.create!(name: "Test Author") }
  let!(:book) { Book.create!(user: user, author: author, title: "Test Book") }

  def json_headers
    { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
  end

  def headers_with_api_key(key = api_key)
    json_headers.merge("X-API-Key" => key)
  end

  context "when API_KEY is set" do
    before do
      ENV["API_KEY"] = api_key
    end

    after do
      ENV.delete("API_KEY")
    end

    describe "protected routes require API key" do
      context "POST /users" do
        it "returns 401 without API key" do
          post "/users", { name: "Test", email: "test@example.com" }.to_json, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          post "/users", { name: "Test", email: "test@example.com" }.to_json, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          expect {
            post "/users", { name: "Test", email: "correctkey@example.com" }.to_json, headers_with_api_key
          }.to change(User, :count).by(1)
          expect(last_response.status).to eq(201)
          user = User.find_by(email: "correctkey@example.com")
          expect(user).to be_present
          expect(user.name).to eq("Test")
        end

        it "succeeds with HTTP_X_API_KEY header variant" do
          headers = json_headers.merge("HTTP_X_API_KEY" => api_key)
          expect {
            post "/users", { name: "Test", email: "httpheader@example.com" }.to_json, headers
          }.to change(User, :count).by(1)
          expect(last_response.status).to eq(201)
        end

        it "succeeds with lowercase x-api-key header variant" do
          headers = json_headers.merge("x-api-key" => api_key)
          expect {
            post "/users", { name: "Test", email: "lowercase@example.com" }.to_json, headers
          }.to change(User, :count).by(1)
          expect(last_response.status).to eq(201)
        end
      end

      context "POST /authors" do
        it "returns 401 without API key" do
          post "/authors", { name: "New Author" }.to_json, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          post "/authors", { name: "New Author" }.to_json, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          expect {
            post "/authors", { name: "New Author" }.to_json, headers_with_api_key
          }.to change(Author, :count).by(1)
          expect(last_response.status).to eq(201)
          author = Author.find_by(name: "New Author")
          expect(author).to be_present
        end
      end

      context "POST /books" do
        it "returns 401 without API key" do
          post "/books", { user_id: user.id, title: "Book", author_name: "Author" }.to_json, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          post "/books", { user_id: user.id, title: "Book", author_name: "Author" }.to_json, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          expect {
            post "/books", { user_id: user.id, title: "Book", author_name: "Author" }.to_json, headers_with_api_key
          }.to change(Book, :count).by(1)
          expect(last_response.status).to eq(201)
          created_book = Book.find_by(title: "Book")
          expect(created_book).to be_present
          expect(created_book.author.name).to eq("Author")
        end
      end

      context "PATCH /books/:id" do
        it "returns 401 without API key" do
          patch "/books/#{book.id}", { status: "reading" }.to_json, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          patch "/books/#{book.id}", { status: "reading" }.to_json, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          expect(book.status).not_to eq("reading")
          patch "/books/#{book.id}", { status: "reading" }.to_json, headers_with_api_key
          expect(last_response.status).to eq(200)
          book.reload
          expect(book.status).to eq("reading")
        end
      end

      context "DELETE /books/:id" do
        let!(:deletable_book) { Book.create!(user: user, author: author, title: "Delete Me") }

        it "returns 401 without API key" do
          delete "/books/#{deletable_book.id}", nil, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          delete "/books/#{deletable_book.id}", nil, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          deletable2 = Book.create!(user: user, author: author, title: "Delete Me 2")
          expect {
            delete "/books/#{deletable2.id}", nil, headers_with_api_key
          }.to change(Book, :count).by(-1)
          expect(last_response.status).to eq(204)
          expect(Book.find_by(id: deletable2.id)).to be_nil
        end
      end

      context "POST /books/:id/tags" do
        it "returns 401 without API key" do
          post "/books/#{book.id}/tags", { names: ["tag1"] }.to_json, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          post "/books/#{book.id}/tags", { names: ["tag1"] }.to_json, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          expect {
            post "/books/#{book.id}/tags", { names: ["tag1"] }.to_json, headers_with_api_key
          }.to change(book.tags, :count).by(1)
          expect(last_response.status).to eq(200)
          book.reload
          expect(book.tags.map(&:name)).to include("tag1")
        end
      end

      context "POST /books/:id/reviews" do
        it "returns 401 without API key" do
          post "/books/#{book.id}/reviews", { body: "Great", rating: 5 }.to_json, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          post "/books/#{book.id}/reviews", { body: "Great", rating: 5 }.to_json, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          expect {
            post "/books/#{book.id}/reviews", { body: "Great", rating: 5 }.to_json, headers_with_api_key
          }.to change(book.reviews, :count).by(1)
          expect(last_response.status).to eq(201)
          book.reload
          review = book.reviews.find_by(body: "Great")
          expect(review).to be_present
          expect(review.rating).to eq(5)
        end
      end

      context "POST /books/:id/reading_sessions" do
        it "returns 401 without API key" do
          post "/books/#{book.id}/reading_sessions", { minutes: 30, date: "2025-01-01" }.to_json, json_headers
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "returns 401 with wrong API key" do
          post "/books/#{book.id}/reading_sessions", { minutes: 30, date: "2025-01-01" }.to_json, headers_with_api_key(wrong_key)
          expect(last_response.status).to eq(401)
          expect(last_response.content_type).to include("application/json")
          expect(JSON.parse(last_response.body)["error"]).to eq("Unauthorized")
        end

        it "succeeds with correct API key" do
          expect {
            post "/books/#{book.id}/reading_sessions", { minutes: 30, date: "2025-01-01" }.to_json, headers_with_api_key
          }.to change(book.reading_sessions, :count).by(1)
          expect(last_response.status).to eq(201)
          book.reload
          session = book.reading_sessions.find_by(date: Date.parse("2025-01-01"))
          expect(session).to be_present
          expect(session.minutes).to eq(30)
        end
      end
    end

    describe "read-only endpoints remain public" do
      it "GET / succeeds without API key" do
        get "/"
        expect(last_response.status).to eq(200)
      end

      it "GET /health succeeds without API key" do
        get "/health"
        expect(last_response.status).to eq(200)
      end

      it "GET /version succeeds without API key" do
        get "/version"
        expect(last_response.status).to eq(200)
      end

      it "GET /books succeeds without API key" do
        get "/books"
        expect(last_response.status).to eq(200)
      end

      it "GET /books/:id succeeds without API key" do
        get "/books/#{book.id}"
        expect(last_response.status).to eq(200)
      end

      it "GET /authors succeeds without API key" do
        get "/authors"
        expect(last_response.status).to eq(200)
      end

      it "GET /tags succeeds without API key" do
        get "/tags"
        expect(last_response.status).to eq(200)
      end

      it "GET /stats succeeds without API key" do
        get "/stats"
        expect(last_response.status).to eq(200)
      end
    end

    describe "header name variants" do
      it "accepts lowercase x-api-key header" do
        headers = json_headers.merge("x-api-key" => api_key)
        expect {
          post "/authors", { name: "Lowercase Header Author" }.to_json, headers
        }.to change(Author, :count).by(1)
        expect(last_response.status).to eq(201)
      end

      it "accepts mixed case X-Api-Key header" do
        headers = json_headers.merge("X-Api-Key" => api_key)
        expect {
          post "/authors", { name: "Mixed Case Author" }.to_json, headers
        }.to change(Author, :count).by(1)
        expect(last_response.status).to eq(201)
      end

      it "rejects malformed header with wrong key" do
        headers = json_headers.merge("x-api-key" => wrong_key)
        post "/authors", { name: "Malformed Author" }.to_json, headers
        expect(last_response.status).to eq(401)
      end
    end

    describe "ENV reloading behavior" do
      it "picks up ENV changes between requests" do
        # First request with original API key
        post "/authors", { name: "Original Key Author" }.to_json, headers_with_api_key
        expect(last_response.status).to eq(201)

        # Change ENV["API_KEY"]
        new_key = "new_secret_key_456"
        ENV["API_KEY"] = new_key

        # Request with old key should fail
        post "/authors", { name: "Old Key Author" }.to_json, headers_with_api_key
        expect(last_response.status).to eq(401)

        # Request with new key should succeed
        headers = json_headers.merge("X-API-Key" => new_key)
        expect {
          post "/authors", { name: "New Key Author" }.to_json, headers
        }.to change(Author, :count).by(1)
        expect(last_response.status).to eq(201)

        # Restore original key
        ENV["API_KEY"] = api_key
      end

      it "picks up ENV deletion between requests" do
        # First request with API key set
        post "/authors", { name: "With Key Author" }.to_json, headers_with_api_key
        expect(last_response.status).to eq(201)

        # Delete ENV["API_KEY"]
        ENV.delete("API_KEY")

        # Request without key should now succeed (auth disabled)
        expect {
          post "/authors", { name: "No Key After Delete" }.to_json, json_headers
        }.to change(Author, :count).by(1)
        expect(last_response.status).to eq(201)

        # Restore API key
        ENV["API_KEY"] = api_key
      end
    end
  end

  context "when API_KEY is not set" do
    before do
      ENV.delete("API_KEY")
    end

    describe "all endpoints work without authentication (backward compatible)" do
      it "POST /users succeeds without API key" do
        post "/users", { name: "Test", email: "nokey@example.com" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "POST /authors succeeds without API key" do
        post "/authors", { name: "No Key Author" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "POST /books succeeds without API key" do
        post "/books", { user_id: user.id, title: "No Key Book", author_name: "Author" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "PATCH /books/:id succeeds without API key" do
        patch "/books/#{book.id}", { status: "reading" }.to_json, json_headers
        expect(last_response.status).to eq(200)
      end

      it "DELETE /books/:id succeeds without API key" do
        deletable = Book.create!(user: user, author: author, title: "Delete No Key")
        delete "/books/#{deletable.id}", nil, json_headers
        expect(last_response.status).to eq(204)
      end

      it "POST /books/:id/tags succeeds without API key" do
        post "/books/#{book.id}/tags", { names: ["tag1"] }.to_json, json_headers
        expect(last_response.status).to eq(200)
      end

      it "POST /books/:id/reviews succeeds without API key" do
        post "/books/#{book.id}/reviews", { body: "Great", rating: 5 }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "POST /books/:id/reading_sessions succeeds without API key" do
        post "/books/#{book.id}/reading_sessions", { minutes: 30, date: "2025-01-01" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "GET /books succeeds without API key" do
        get "/books"
        expect(last_response.status).to eq(200)
      end

      it "GET /authors succeeds without API key" do
        get "/authors"
        expect(last_response.status).to eq(200)
      end
    end
  end

  context "when API_KEY is empty string" do
    before do
      ENV["API_KEY"] = ""
    end

    after do
      ENV.delete("API_KEY")
    end

    describe "all endpoints work without authentication (backward compatible with empty string)" do
      it "POST /users succeeds without API key" do
        post "/users", { name: "Test", email: "emptykey@example.com" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "POST /authors succeeds without API key" do
        post "/authors", { name: "Empty Key Author" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "POST /books succeeds without API key" do
        post "/books", { user_id: user.id, title: "Empty Key Book", author_name: "Author" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "PATCH /books/:id succeeds without API key" do
        patch "/books/#{book.id}", { status: "reading" }.to_json, json_headers
        expect(last_response.status).to eq(200)
      end

      it "DELETE /books/:id succeeds without API key" do
        deletable = Book.create!(user: user, author: author, title: "Delete Empty Key")
        delete "/books/#{deletable.id}", nil, json_headers
        expect(last_response.status).to eq(204)
      end

      it "POST /books/:id/tags succeeds without API key" do
        post "/books/#{book.id}/tags", { names: ["tag1"] }.to_json, json_headers
        expect(last_response.status).to eq(200)
      end

      it "POST /books/:id/reviews succeeds without API key" do
        post "/books/#{book.id}/reviews", { body: "Great", rating: 5 }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end

      it "POST /books/:id/reading_sessions succeeds without API key" do
        post "/books/#{book.id}/reading_sessions", { minutes: 30, date: "2025-01-01" }.to_json, json_headers
        expect(last_response.status).to eq(201)
      end
    end
  end
end
