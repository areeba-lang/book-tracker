require "spec_helper"
require "csv"

RSpec.describe "Books Export Functionality", type: :request do
  let!(:user1) { User.create!(email: "export1@ex.com", name: "User 1") }
  let!(:user2) { User.create!(email: "export2@ex.com", name: "User 2") }
  let!(:author1) { Author.create!(name: "Author One") }
  let!(:author2) { Author.create!(name: "Author Two") }
  let!(:tag1) { Tag.create!(name: "sci-fi") }
  let!(:tag2) { Tag.create!(name: "classic") }
  let!(:tag3) { Tag.create!(name: "fiction") }

  let!(:book1) do
    book = Book.create!(user: user1, author: author1, title: "Dune", status: "finished", rating: 5)
    BookTag.create!(book: book, tag: tag1)
    BookTag.create!(book: book, tag: tag2)
    book.reviews.create!(body: "Great book", rating: 5)
    book.reading_sessions.create!(minutes: 60, date: Date.today)
    book.reading_sessions.create!(minutes: 40, date: Date.today - 1)
    book
  end

  let!(:book2) do
    book = Book.create!(user: user1, author: author2, title: "Foundation", status: "reading", rating: 4)
    BookTag.create!(book: book, tag: tag3)
    book.reviews.create!(body: "Good read", rating: 4)
    book.reviews.create!(body: "Interesting", rating: 4)
    book.reading_sessions.create!(minutes: 30, date: Date.today)
    book
  end

  let!(:book3) do
    book = Book.create!(user: user2, author: author1, title: "Another Book", status: "to_read", rating: 0)
    BookTag.create!(book: book, tag: tag1)
    book
  end

  describe "GET /books/export" do
    context "JSON export" do
      context "when format=json" do
        it "returns JSON with correct Content-Type header" do
          get "/books/export?format=json"
          expect(last_response.status).to eq(200)
          expect(last_response.content_type).to include("application/json")
        end

        it "returns all books with complete structure" do
          get "/books/export?format=json"
          expect(last_response).to be_ok
          body = JSON.parse(last_response.body)
          
          expect(body).to have_key("books")
          expect(body).to have_key("meta")
          expect(body["books"]).to be_an(Array)
          expect(body["books"].length).to eq(3)
          
          first_book = body["books"].first
          expect(first_book).to have_key("id")
          expect(first_book).to have_key("title")
          expect(first_book).to have_key("status")
          expect(first_book).to have_key("rating")
          expect(first_book).to have_key("total_minutes")
          expect(first_book).to have_key("author")
          expect(first_book).to have_key("tags")
          expect(first_book).to have_key("reviews")
          expect(first_book).to have_key("reading_sessions")
          expect(first_book).to have_key("created_at")
          expect(first_book).to have_key("updated_at")
        end

        it "includes all book relationships correctly" do
          get "/books/export?format=json"
          body = JSON.parse(last_response.body)
          dune_book = body["books"].find { |b| b["title"] == "Dune" }
          
          expect(dune_book["author"]["id"]).to eq(author1.id)
          expect(dune_book["author"]["name"]).to eq("Author One")
          expect(dune_book["tags"].length).to eq(2)
          expect(dune_book["tags"].map { |t| t["name"] }).to contain_exactly("sci-fi", "classic")
          expect(dune_book["reviews"].length).to eq(1)
          expect(dune_book["reviews"].first["body"]).to eq("Great book")
          expect(dune_book["reading_sessions"].length).to eq(2)
          expect(dune_book["total_minutes"]).to eq(100)
        end

        it "includes meta information" do
          get "/books/export?format=json"
          body = JSON.parse(last_response.body)
          
          expect(body["meta"]).to have_key("total")
          expect(body["meta"]).to have_key("format")
          expect(body["meta"]).to have_key("exported_at")
          expect(body["meta"]["total"]).to eq(3)
          expect(body["meta"]["format"]).to eq("json")
          expect(body["meta"]["exported_at"]).to be_present
        end

        it "filters by user_id parameter" do
          get "/books/export?format=json&user_id=#{user1.id}"
          body = JSON.parse(last_response.body)
          
          expect(body["books"].length).to eq(2)
          expect(body["books"].map { |b| b["title"] }).to contain_exactly("Dune", "Foundation")
          expect(body["meta"]["total"]).to eq(2)
        end

        it "filters by status parameter" do
          get "/books/export?format=json&status=finished"
          body = JSON.parse(last_response.body)
          
          expect(body["books"].length).to eq(1)
          expect(body["books"].first["title"]).to eq("Dune")
          expect(body["books"].first["status"]).to eq("finished")
        end

        it "filters by tag parameter" do
          get "/books/export?format=json&tag=sci-fi"
          body = JSON.parse(last_response.body)
          
          book_titles = body["books"].map { |b| b["title"] }
          expect(book_titles).to include("Dune", "Another Book")
          expect(book_titles).not_to include("Foundation")
          body["books"].each do |book|
            tag_names = book["tags"].map { |t| t["name"] }
            expect(tag_names).to include("sci-fi")
          end
        end

        it "applies multiple filters together" do
          get "/books/export?format=json&user_id=#{user1.id}&status=reading"
          body = JSON.parse(last_response.body)
          
          expect(body["books"].length).to eq(1)
          expect(body["books"].first["title"]).to eq("Foundation")
          expect(body["books"].first["status"]).to eq("reading")
        end

        it "handles empty results gracefully" do
          get "/books/export?format=json&status=finished&user_id=99999"
          body = JSON.parse(last_response.body)
          
          expect(body["books"]).to eq([])
          expect(body["meta"]["total"]).to eq(0)
        end
      end
    end

    context "CSV export" do
      context "when format=csv" do
        it "returns CSV with correct Content-Type header" do
          get "/books/export?format=csv"
          expect(last_response.status).to eq(200)
          expect(last_response.content_type).to include("text/csv")
        end

        it "includes Content-Disposition header with filename" do
          get "/books/export?format=csv"
          expect(last_response.headers["Content-Disposition"]).to include("attachment")
          expect(last_response.headers["Content-Disposition"]).to include("filename=\"books_export.csv\"")
        end

        it "returns valid CSV with correct headers" do
          get "/books/export?format=csv"
          expect(last_response).to be_ok
          
          csv = CSV.parse(last_response.body)
          expect(csv.length).to be >= 2 # At least header + 1 row
          
          headers = csv.first
          expected_headers = [
            "id", "title", "status", "rating", "total_minutes",
            "author_id", "author_name", "tags",
            "review_count", "average_review_rating",
            "reading_session_count",
            "created_at", "updated_at"
          ]
          expected_headers.each do |header|
            expect(headers).to include(header)
          end
        end

        it "includes all books with flattened data" do
          get "/books/export?format=csv"
          csv = CSV.parse(last_response.body, headers: true)
          
          expect(csv.length).to eq(3)
          
          dune_row = csv.find { |row| row["title"] == "Dune" }
          expect(dune_row).to be_present
          expect(dune_row["status"]).to eq("finished")
          expect(dune_row["rating"]).to eq("5")
          expect(dune_row["total_minutes"]).to eq("100")
          expect(dune_row["author_id"]).to eq(author1.id.to_s)
          expect(dune_row["author_name"]).to eq("Author One")
          expect(dune_row["tags"]).to include("sci-fi")
          expect(dune_row["tags"]).to include("classic")
        end

        it "handles comma-separated tags correctly" do
          get "/books/export?format=csv"
          csv = CSV.parse(last_response.body, headers: true)
          
          dune_row = csv.find { |row| row["title"] == "Dune" }
          tag_values = dune_row["tags"].split(",").map(&:strip)
          expect(tag_values).to contain_exactly("sci-fi", "classic")
        end

        it "calculates review statistics correctly" do
          get "/books/export?format=csv"
          csv = CSV.parse(last_response.body, headers: true)
          
          foundation_row = csv.find { |row| row["title"] == "Foundation" }
          expect(foundation_row["review_count"]).to eq("2")
          expect(foundation_row["average_review_rating"]).to eq("4.0")
        end

        it "calculates reading session count correctly" do
          get "/books/export?format=csv"
          csv = CSV.parse(last_response.body, headers: true)
          
          dune_row = csv.find { |row| row["title"] == "Dune" }
          expect(dune_row["reading_session_count"]).to eq("2")
        end

        it "handles books with no reviews or sessions" do
          get "/books/export?format=csv"
          csv = CSV.parse(last_response.body, headers: true)
          
          another_row = csv.find { |row| row["title"] == "Another Book" }
          expect(another_row["review_count"]).to eq("0")
          expect(another_row["average_review_rating"]).to eq("0.0")
          expect(another_row["reading_session_count"]).to eq("0")
        end

        it "filters by user_id parameter" do
          get "/books/export?format=csv&user_id=#{user1.id}"
          csv = CSV.parse(last_response.body, headers: true)
          
          expect(csv.length).to eq(2)
          titles = csv.map { |row| row["title"] }
          expect(titles).to contain_exactly("Dune", "Foundation")
        end

        it "filters by status parameter" do
          get "/books/export?format=csv&status=finished"
          csv = CSV.parse(last_response.body, headers: true)
          
          expect(csv.length).to eq(1)
          expect(csv.first["title"]).to eq("Dune")
          expect(csv.first["status"]).to eq("finished")
        end

        it "filters by tag parameter" do
          get "/books/export?format=csv&tag=sci-fi"
          csv = CSV.parse(last_response.body, headers: true)
          
          titles = csv.map { |row| row["title"] }
          expect(titles).to include("Dune", "Another Book")
          expect(titles).not_to include("Foundation")
        end

        it "applies multiple filters together" do
          get "/books/export?format=csv&user_id=#{user1.id}&status=reading"
          csv = CSV.parse(last_response.body, headers: true)
          
          expect(csv.length).to eq(1)
          expect(csv.first["title"]).to eq("Foundation")
          expect(csv.first["status"]).to eq("reading")
        end

        it "handles empty results with headers only" do
          get "/books/export?format=csv&status=finished&user_id=99999"
          csv = CSV.parse(last_response.body, headers: true)
          
          expect(csv.length).to eq(0)
          # Should have headers but no data rows
          headers = CSV.parse(last_response.body).first
          expect(headers).to be_present
        end

        it "properly escapes CSV values containing commas" do
          book_with_comma = Book.create!(
            user: user1,
            author: author1,
            title: "Book, With, Commas",
            status: "reading"
          )
          get "/books/export?format=csv"
          csv = CSV.parse(last_response.body, headers: true)
          
          comma_book_row = csv.find { |row| row["title"] == "Book, With, Commas" }
          expect(comma_book_row).to be_present
          expect(comma_book_row["title"]).to eq("Book, With, Commas")
        end
      end
    end

    context "error handling" do
      it "returns 400 when format parameter is missing" do
        get "/books/export"
        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to include("format")
        expect(body["error"]).to include("required")
      end

      it "returns 400 when format is invalid" do
        get "/books/export?format=xml"
        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to include("Invalid format")
        expect(body["error"]).to match(/json.*csv/i)
      end

      it "returns 400 when format is empty string" do
        get "/books/export?format="
        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to be_present
      end

      it "returns 400 for case-insensitive invalid format" do
        get "/books/export?format=JSON" # Should work, but test invalid ones
        # JSON should be case-insensitive (accept JSON, json, Json)
        # But let's test a truly invalid one
        get "/books/export?format=pdf"
        expect(last_response.status).to eq(400)
      end

      it "handles invalid status filter gracefully" do
        get "/books/export?format=json&status=invalid_status"
        # Should either filter to empty results or return 400
        # Based on issue, invalid filters return 400
        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body["error"]).to be_present
      end

      it "handles non-existent user_id filter" do
        get "/books/export?format=json&user_id=999999"
        # Should return empty results, not error (valid filter, just no matches)
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["books"]).to eq([])
      end

      it "handles invalid user_id format" do
        get "/books/export?format=json&user_id=not_a_number"
        # ActiveRecord will treat non-numeric user_id as not matching any records
        # So should return 200 with empty results, not crash
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["books"]).to eq([])
        expect(body["meta"]["total"]).to eq(0)
      end
    end

    context "edge cases" do
      it "handles no books in database" do
        Book.destroy_all
        ReadingSession.destroy_all
        
        get "/books/export?format=json"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books"]).to eq([])
        expect(body["meta"]["total"]).to eq(0)
      end

      it "handles no filters (exports all books)" do
        get "/books/export?format=json"
        body = JSON.parse(last_response.body)
        expect(body["books"].length).to eq(3)
        expect(body["meta"]["total"]).to eq(3)
      end

      it "handles books with no tags" do
        book_no_tags = Book.create!(
          user: user1,
          author: author1,
          title: "No Tags Book",
          status: "reading"
        )
        
        get "/books/export?format=json&title=No Tags Book"
        # Note: title filter might not be supported, but let's test the book exists
        get "/books/export?format=json"
        body = JSON.parse(last_response.body)
        no_tags_book = body["books"].find { |b| b["title"] == "No Tags Book" }
        expect(no_tags_book["tags"]).to eq([])
      end

      it "handles books with no reviews" do
        get "/books/export?format=csv"
        csv = CSV.parse(last_response.body, headers: true)
        another_row = csv.find { |row| row["title"] == "Another Book" }
        expect(another_row["review_count"]).to eq("0")
        expect(another_row["average_review_rating"]).to eq("0.0")
      end

      it "handles books with no reading sessions" do
        get "/books/export?format=csv"
        csv = CSV.parse(last_response.body, headers: true)
        another_row = csv.find { |row| row["title"] == "Another Book" }
        expect(another_row["reading_session_count"]).to eq("0")
      end

      it "handles books with rating 0" do
        get "/books/export?format=json"
        body = JSON.parse(last_response.body)
        zero_rating_book = body["books"].find { |b| b["title"] == "Another Book" }
        expect(zero_rating_book["rating"]).to eq(0)
      end
    end

    context "data consistency" do
      it "JSON and CSV exports return same books for same filters" do
        json_response = get "/books/export?format=json&user_id=#{user1.id}"
        json_body = JSON.parse(json_response.body)
        
        csv_response = get "/books/export?format=csv&user_id=#{user1.id}"
        csv_data = CSV.parse(csv_response.body, headers: true)
        
        json_titles = json_body["books"].map { |b| b["title"] }.sort
        csv_titles = csv_data.map { |row| row["title"] }.sort
        
        expect(json_titles).to eq(csv_titles)
      end

      it "meta total count matches actual books array length in JSON" do
        get "/books/export?format=json"
        body = JSON.parse(last_response.body)
        expect(body["meta"]["total"]).to eq(body["books"].length)
      end
    end
  end
end

