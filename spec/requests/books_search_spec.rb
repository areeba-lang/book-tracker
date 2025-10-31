require "spec_helper"

RSpec.describe "Books search functionality", type: :request do
  let!(:user) { User.create!(email: "search@example.com", name: "Search User") }
  let!(:author1) { Author.create!(name: "Frank Herbert") }
  let!(:author2) { Author.create!(name: "Isaac Asimov") }
  let!(:author3) { Author.create!(name: "Herbert Wells") }

  let!(:book1) { Book.create!(user: user, author: author1, title: "Dune") }
  let!(:book2) { Book.create!(user: user, author: author1, title: "Dune Messiah") }
  let!(:book3) { Book.create!(user: user, author: author2, title: "Foundation") }
  let!(:book4) { Book.create!(user: user, author: author3, title: "The Time Machine") }

  describe "GET /books with q parameter" do
    context "searching by title" do
      it "finds books with matching title (partial match)" do
        get "/books?q=dune"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune", "Dune Messiah")
        expect(titles).not_to include("Foundation", "The Time Machine")
      end

      it "finds books with case-insensitive title match" do
        get "/books?q=DUNE"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune", "Dune Messiah")
      end

      it "finds books with partial title match" do
        get "/books?q=found"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Foundation")
        expect(titles).not_to include("Dune", "Dune Messiah", "The Time Machine")
      end

      it "returns empty array when no title matches" do
        get "/books?q=nonexistent"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books"]).to eq([])
        expect(body["meta"]["total"]).to eq(0)
      end
    end

    context "searching by author name" do
      it "finds books with matching author name (partial match)" do
        get "/books?q=herbert"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune", "Dune Messiah", "The Time Machine")
        expect(titles).not_to include("Foundation")
      end

      it "finds books with case-insensitive author name match" do
        get "/books?q=HERBERT"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune", "Dune Messiah", "The Time Machine")
      end

      it "finds books by partial author name match" do
        get "/books?q=asimov"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Foundation")
        expect(titles).not_to include("Dune", "Dune Messiah", "The Time Machine")
      end

      it "finds books matching either title OR author" do
        get "/books?q=time"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("The Time Machine")
      end
    end

    context "search combined with existing filters" do
      it "works with status filter" do
        book1.update!(status: "reading")
        book2.update!(status: "to_read")
        get "/books?q=dune&status=reading"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune")
        expect(titles).not_to include("Dune Messiah")
      end

      it "works with user_id filter" do
        other_user = User.create!(email: "other@example.com", name: "Other")
        other_book = Book.create!(user: other_user, author: author1, title: "Dune Copy")
        get "/books?q=dune&user_id=#{user.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune", "Dune Messiah")
        expect(titles).not_to include("Dune Copy")
      end

      it "works with tag filter" do
        tag = Tag.create!(name: "sci-fi")
        BookTag.create!(book: book1, tag: tag)
        get "/books?q=dune&tag=sci-fi"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune")
        expect(titles).not_to include("Dune Messiah")
      end

      it "works with existing author filter" do
        get "/books?q=dune&author=Frank"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to include("Dune", "Dune Messiah")
      end
    end

    context "search with pagination and sorting" do
      before do
        5.times { |i| Book.create!(user: user, author: author1, title: "Dune Series #{i}") }
      end

      it "works with pagination" do
        get "/books?q=dune&page=1&per_page=2"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books"].size).to eq(2)
        expect(body["meta"]["total"]).to be >= 7 # At least Dune, Dune Messiah, and 5 series books
        expect(body["meta"]["page"]).to eq(1)
        expect(body["meta"]["per_page"]).to eq(2)
      end

      it "works with sorting" do
        get "/books?q=dune&sort=title&dir=asc"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        titles = body["books"].map { |b| b["title"] }
        expect(titles).to eq(titles.sort)
      end
    end

    context "edge cases" do
      it "returns all books when q parameter is empty string" do
        get "/books?q="
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books"].size).to eq(4)
      end

      it "returns all books when q parameter is whitespace" do
        get "/books?q=   "
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books"].size).to eq(4)
      end

      it "handles special characters in search term" do
        get "/books?q=dune%20"
        expect(last_response).to be_ok
        # Should not error, may return results or empty
        expect(last_response.status).to eq(200)
      end
    end

    context "backward compatibility" do
      it "works without q parameter (existing functionality)" do
        get "/books"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books"]).to be_an(Array)
        expect(body["meta"]).to include("page", "per_page", "total")
      end

      it "existing filters work without q parameter" do
        get "/books?status=reading&tag=sci-fi"
        expect(last_response).to be_ok
        expect(last_response.status).to eq(200)
      end
    end
  end
end

