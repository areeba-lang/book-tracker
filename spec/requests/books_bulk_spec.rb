require "spec_helper"

RSpec.describe "Books Bulk Operations", type: :request do
  let!(:user) { User.create!(email: "bulk@example.com", name: "Bulk User") }
  let!(:existing_author) { Author.create!(name: "Existing Author") }

  def json_headers
    { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
  end

  def headers_with_api_key(key = "test_key")
    json_headers.merge("X-API-Key" => key)
  end

  before do
    ENV["API_KEY"] = "test_key"
  end

  after do
    ENV.delete("API_KEY")
  end

  describe "POST /books/bulk" do
    context "successful bulk creation" do
      it "creates multiple books in single request" do
        payload = {
          books: [
            { user_id: user.id, title: "Book One", author_name: "Author One" },
            { user_id: user.id, title: "Book Two", author_name: "Author Two" },
            { user_id: user.id, title: "Book Three", author_name: "Author Three" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        
        expect(body).to have_key("results")
        expect(body).to have_key("meta")
        expect(body["results"].length).to eq(3)
        expect(body["meta"]["total"]).to eq(3)
        expect(body["meta"]["successful"]).to eq(3)
        expect(body["meta"]["failed"]).to eq(0)
      end

      it "includes full book objects in successful results" do
        payload = {
          books: [
            { user_id: user.id, title: "Dune", author_name: "Frank Herbert", status: "finished", rating: 5 }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        result = body["results"].first
        
        expect(result["success"]).to eq(true)
        expect(result).to have_key("book")
        expect(result["book"]).to have_key("id")
        expect(result["book"]).to have_key("title")
        expect(result["book"]).to have_key("status")
        expect(result["book"]).to have_key("rating")
        expect(result["book"]).to have_key("author")
        expect(result["book"]).to have_key("tags")
        expect(result["book"]).to have_key("reviews")
        expect(result["book"]).to have_key("reading_sessions")
        expect(result["book"]["title"]).to eq("Dune")
        expect(result["book"]["status"]).to eq("finished")
        expect(result["book"]["rating"]).to eq(5)
      end

      it "creates all books in database" do
        initial_count = Book.count
        
        payload = {
          books: [
            { user_id: user.id, title: "B1", author_name: "A1" },
            { user_id: user.id, title: "B2", author_name: "A2" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(Book.count).to eq(initial_count + 2)
        expect(Book.pluck(:title)).to include("B1", "B2")
      end

      it "handles optional fields correctly" do
        payload = {
          books: [
            { user_id: user.id, title: "With Status", author_name: "Author", status: "reading" },
            { user_id: user.id, title: "With Rating", author_name: "Author", rating: 4 },
            { user_id: user.id, title: "With Both", author_name: "Author", status: "finished", rating: 5 },
            { user_id: user.id, title: "Minimal", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        results = body["results"]
        
        expect(results[0]["book"]["status"]).to eq("reading")
        expect(results[1]["book"]["rating"]).to eq(4)
        expect(results[2]["book"]["status"]).to eq("finished")
        expect(results[2]["book"]["rating"]).to eq(5)
        expect(results[3]["book"]["status"]).to be_present # default status
      end

      it "reuses author when same author appears multiple times" do
        payload = {
          books: [
            { user_id: user.id, title: "Book 1", author_name: "Same Author" },
            { user_id: user.id, title: "Book 2", author_name: "Same Author" },
            { user_id: user.id, title: "Book 3", author_name: "Same Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        
        authors = Author.where(name: "Same Author")
        expect(authors.count).to eq(1)
        
        author_id = authors.first.id
        books = Book.where(author_id: author_id)
        expect(books.count).to eq(3)
      end
    end

    context "partial success" do
      it "handles mix of valid and invalid books" do
        payload = {
          books: [
            { user_id: user.id, title: "Valid Book", author_name: "Author" },
            { title: "Missing user_id", author_name: "Author" }, # Invalid
            { user_id: user.id, author_name: "Missing title" }, # Invalid
            { user_id: user.id, title: "Another Valid", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        
        expect(body["meta"]["total"]).to eq(4)
        expect(body["meta"]["successful"]).to eq(2)
        expect(body["meta"]["failed"]).to eq(2)
      end

      it "includes error messages for failed books" do
        payload = {
          books: [
            { user_id: user.id, title: "", author_name: "Author" }, # Invalid: empty title
            { user_id: user.id, title: "Valid", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        failed_result = body["results"].find { |r| r["success"] == false }
        
        expect(failed_result).to be_present
        expect(failed_result).to have_key("error")
        expect(failed_result["error"]).to be_a(String)
        expect(failed_result["error"]).not_to be_empty
      end

      it "includes index for failed books" do
        payload = {
          books: [
            { user_id: user.id, title: "Valid 1", author_name: "Author" },
            { user_id: user.id, title: "", author_name: "Author" }, # Invalid at index 1
            { user_id: user.id, title: "Valid 2", author_name: "Author" },
            { title: "Missing user", author_name: "Author" } # Invalid at index 3
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        failed_results = body["results"].select { |r| r["success"] == false }
        
        failed_results.each do |result|
          expect(result).to have_key("index")
          expect(result["index"]).to be_a(Integer)
          expect(result["index"]).to be_between(0, 3)
        end
      end

      it "creates valid books even when some fail" do
        initial_count = Book.count
        
        payload = {
          books: [
            { user_id: user.id, title: "Valid Book 1", author_name: "Author" },
            { user_id: user.id, title: "", author_name: "Author" }, # Invalid
            { user_id: user.id, title: "Valid Book 2", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(Book.count).to eq(initial_count + 2)
        expect(Book.pluck(:title)).to include("Valid Book 1", "Valid Book 2")
        expect(Book.pluck(:title)).not_to include("")
      end

      it "returns success:true for valid books and success:false for invalid" do
        payload = {
          books: [
            { user_id: user.id, title: "Good", author_name: "Author" },
            { title: "Bad", author_name: "Author" } # Missing user_id
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        
        good_result = body["results"].find { |r| r["success"] == true }
        bad_result = body["results"].find { |r| r["success"] == false }
        
        expect(good_result).to be_present
        expect(good_result).to have_key("book")
        expect(bad_result).to be_present
        expect(bad_result).to have_key("error")
        expect(bad_result).not_to have_key("book")
      end
    end

    context "error handling" do
      it "returns 400 when books parameter is missing" do
        post "/books/bulk", {}.to_json, headers_with_api_key

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to include("books")
        expect(body["error"]).to include("required")
      end

      it "returns 400 when books is not an array" do
        post "/books/bulk", { books: "not an array" }.to_json, headers_with_api_key

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to include("array")
      end

      it "returns 422 when books array is empty" do
        post "/books/bulk", { books: [] }.to_json, headers_with_api_key

        expect(last_response.status).to eq(422)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to include("empty")
      end

      it "returns 400 when books array exceeds 100 items" do
        large_array = Array.new(101) { |i| { user_id: user.id, title: "Book #{i}", author_name: "Author" } }
        post "/books/bulk", { books: large_array }.to_json, headers_with_api_key

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to include("100")
      end

      it "allows exactly 100 books" do
        large_array = Array.new(100) { |i| { user_id: user.id, title: "Book #{i}", author_name: "Author #{i}" } }
        post "/books/bulk", { books: large_array }.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["meta"]["total"]).to eq(100)
        expect(body["meta"]["successful"]).to eq(100)
      end

      it "validates individual book user_id" do
        payload = {
          books: [
            { user_id: 99999, title: "Book", author_name: "Author" } # Non-existent user
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        result = body["results"].first
        
        expect(result["success"]).to eq(false)
        expect(result["error"]).to include("User")
      end

      it "validates individual book title" do
        payload = {
          books: [
            { user_id: user.id, author_name: "Author" } # Missing title
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        result = body["results"].first
        
        expect(result["success"]).to eq(false)
        expect(result["error"]).to include("title")
      end

      it "validates individual book author_name" do
        payload = {
          books: [
            { user_id: user.id, title: "Book" } # Missing author_name
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        result = body["results"].first
        
        expect(result["success"]).to eq(false)
        expect(result["error"]).to include("author")
      end

      it "validates individual book status values" do
        payload = {
          books: [
            { user_id: user.id, title: "Book", author_name: "Author", status: "invalid_status" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        result = body["results"].first
        
        expect(result["success"]).to eq(false)
        expect(result["error"]).to include("status")
      end

      it "validates individual book rating values" do
        payload = {
          books: [
            { user_id: user.id, title: "Book", author_name: "Author", rating: 10 } # Invalid: > 5
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        result = body["results"].first
        
        expect(result["success"]).to eq(false)
        expect(result["error"]).to include("rating")
      end

      it "requires API key authentication" do
        payload = { books: [{ user_id: user.id, title: "Book", author_name: "Author" }] }
        post "/books/bulk", payload.to_json, json_headers

        expect(last_response.status).to eq(401)
      end

      it "returns 400 for invalid JSON" do
        post "/books/bulk", "not json", headers_with_api_key

        expect(last_response.status).to eq(400)
      end
    end

    context "edge cases" do
      it "handles single book in array" do
        payload = {
          books: [
            { user_id: user.id, title: "Single Book", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["meta"]["total"]).to eq(1)
        expect(body["meta"]["successful"]).to eq(1)
        expect(body["results"].length).to eq(1)
      end

      it "allows duplicate books (same title and author)" do
        payload = {
          books: [
            { user_id: user.id, title: "Duplicate", author_name: "Author" },
            { user_id: user.id, title: "Duplicate", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["meta"]["successful"]).to eq(2)
        
        books = Book.where(title: "Duplicate")
        expect(books.count).to eq(2)
      end

      it "handles books with same title but different authors" do
        payload = {
          books: [
            { user_id: user.id, title: "Same Title", author_name: "Author One" },
            { user_id: user.id, title: "Same Title", author_name: "Author Two" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["meta"]["successful"]).to eq(2)
        
        books = Book.where(title: "Same Title")
        expect(books.count).to eq(2)
        expect(books.pluck(:author_id).uniq.length).to eq(2)
      end

      it "handles books with same author appearing multiple times" do
        payload = {
          books: [
            { user_id: user.id, title: "Book 1", author_name: "Repeated Author" },
            { user_id: user.id, title: "Book 2", author_name: "Repeated Author" },
            { user_id: user.id, title: "Book 3", author_name: "Repeated Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        
        author = Author.find_by(name: "Repeated Author")
        expect(author).to be_present
        expect(author.books.count).to eq(3)
      end

      it "handles rating 0 correctly" do
        payload = {
          books: [
            { user_id: user.id, title: "Book", author_name: "Author", rating: 0 }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["results"].first["book"]["rating"]).to eq(0)
      end

      it "handles rating 5 correctly" do
        payload = {
          books: [
            { user_id: user.id, title: "Book", author_name: "Author", rating: 5 }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["results"].first["book"]["rating"]).to eq(5)
      end

      it "returns results in same order as input" do
        payload = {
          books: [
            { user_id: user.id, title: "First", author_name: "Author" },
            { user_id: user.id, title: "Second", author_name: "Author" },
            { user_id: user.id, title: "Third", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        titles = body["results"].map { |r| r["book"]["title"] }
        expect(titles).to eq(["First", "Second", "Third"])
      end
    end

    context "meta information" do
      it "correctly counts total, successful, and failed" do
        payload = {
          books: [
            { user_id: user.id, title: "Valid 1", author_name: "Author" },
            { user_id: user.id, title: "Valid 2", author_name: "Author" },
            { title: "Invalid 1", author_name: "Author" }, # Missing user_id
            { user_id: user.id, title: "Valid 3", author_name: "Author" },
            { user_id: user.id, author_name: "Invalid 2" } # Missing title
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        meta = body["meta"]
        
        expect(meta["total"]).to eq(5)
        expect(meta["successful"]).to eq(3)
        expect(meta["failed"]).to eq(2)
        expect(meta["successful"] + meta["failed"]).to eq(meta["total"])
      end

      it "has all required meta fields" do
        payload = {
          books: [
            { user_id: user.id, title: "Book", author_name: "Author" }
          ]
        }
        post "/books/bulk", payload.to_json, headers_with_api_key

        body = JSON.parse(last_response.body)
        meta = body["meta"]
        
        expect(meta).to have_key("total")
        expect(meta).to have_key("successful")
        expect(meta).to have_key("failed")
        expect(meta["total"]).to be_a(Integer)
        expect(meta["successful"]).to be_a(Integer)
        expect(meta["failed"]).to be_a(Integer)
      end
    end
  end
end

