require "spec_helper"

RSpec.describe "Enhanced Stats endpoint", type: :request do
  let!(:user1) { User.create!(email: "stats1@ex.com", name: "User 1") }
  let!(:user2) { User.create!(email: "stats2@ex.com", name: "User 2") }
  let!(:author1) { Author.create!(name: "Author One") }
  let!(:author2) { Author.create!(name: "Author Two") }

  describe "GET /stats" do
    context "status breakdown" do
      before do
        Book.create!(user: user1, author: author1, title: "To Read 1", status: "to_read")
        Book.create!(user: user1, author: author1, title: "To Read 2", status: "to_read")
        Book.create!(user: user1, author: author1, title: "Reading 1", status: "reading")
        Book.create!(user: user1, author: author1, title: "Finished 1", status: "finished")
        Book.create!(user: user1, author: author1, title: "Finished 2", status: "finished")
      end

      it "returns correct status counts" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["to_read_count"]).to eq(2)
        expect(body["reading_count"]).to eq(1)
        expect(body["finished_count"]).to eq(2)
      end

      it "includes finished_count matching total_finished (backward compatibility)" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["finished_count"]).to eq(body["total_finished"])
      end
    end

    context "rating analytics" do
      before do
        Book.create!(user: user1, author: author1, title: "Book 1", status: "finished", rating: 5)
        Book.create!(user: user1, author: author1, title: "Book 2", status: "finished", rating: 4)
        Book.create!(user: user1, author: author1, title: "Book 3", status: "finished", rating: 4)
        Book.create!(user: user1, author: author1, title: "Book 4", status: "finished", rating: 3)
        Book.create!(user: user1, author: author1, title: "Book 5", status: "finished", rating: 0) # Should be excluded
        Book.create!(user: user1, author: author1, title: "Book 6", status: "reading", rating: 0) # Should be excluded
      end

      it "calculates average_rating excluding books with rating 0" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        # (5 + 4 + 4 + 3) / 4 = 4.0
        expect(body["average_rating"]).to eq(4.0)
      end

      it "returns null for average_rating when no books have ratings" do
        Book.where(user: user1).update_all(rating: 0)
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["average_rating"]).to be_nil
      end

      it "counts total_rated_books correctly (excludes rating 0)" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["total_rated_books"]).to eq(4)
      end

      it "returns rating_distribution with counts for each rating 1-5" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["rating_distribution"]).to be_a(Hash)
        expect(body["rating_distribution"]["1"]).to eq(0)
        expect(body["rating_distribution"]["2"]).to eq(0)
        expect(body["rating_distribution"]["3"]).to eq(1)
        expect(body["rating_distribution"]["4"]).to eq(2)
        expect(body["rating_distribution"]["5"]).to eq(1)
      end

      it "includes all rating levels 1-5 in distribution even when count is 0" do
        # Clear existing books and create only one with rating 5
        Book.where(user: user1).destroy_all
        Book.create!(user: user1, author: author1, title: "Only 5", status: "finished", rating: 5)
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        dist = body["rating_distribution"]
        expect(dist.keys.sort).to eq(["1", "2", "3", "4", "5"])
        expect(dist["1"]).to eq(0)
        expect(dist["2"]).to eq(0)
        expect(dist["3"]).to eq(0)
        expect(dist["4"]).to eq(0)
        expect(dist["5"]).to eq(1)
      end
    end

    context "reading session analytics" do
      let!(:book1) { Book.create!(user: user1, author: author1, title: "Book 1", status: "reading") }
      let!(:book2) { Book.create!(user: user1, author: author1, title: "Book 2", status: "reading") }
      let!(:book3) { Book.create!(user: user1, author: author1, title: "Book 3", status: "reading") }

      before do
        # Book 1: 3 sessions totaling 60 minutes (avg 20)
        book1.reading_sessions.create!(minutes: 30, date: Date.today)
        book1.reading_sessions.create!(minutes: 20, date: Date.today - 1)
        book1.reading_sessions.create!(minutes: 10, date: Date.today - 2)
        
        # Book 2: 2 sessions totaling 50 minutes (avg 25)
        book2.reading_sessions.create!(minutes: 25, date: Date.today)
        book2.reading_sessions.create!(minutes: 25, date: Date.today - 1)
        
        # Book 3: no sessions
      end

      it "counts total_reading_sessions across all books" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["total_reading_sessions"]).to eq(5)
      end

      it "calculates average_session_minutes rounded to 2 decimal places" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        # Total: 110 minutes, Sessions: 5, Average: 22.0
        expect(body["average_session_minutes"]).to eq(22.0)
      end

      it "returns null for average_session_minutes when no sessions exist" do
        ReadingSession.where(book: [book1, book2, book3]).destroy_all
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["average_session_minutes"]).to be_nil
      end

      it "counts books_with_sessions (books that have at least one session)" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books_with_sessions"]).to eq(2) # book1 and book2 have sessions, book3 doesn't
      end

      it "returns 0 for books_with_sessions when no books have sessions" do
        ReadingSession.where(book: [book1, book2, book3]).destroy_all
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        expect(body["books_with_sessions"]).to eq(0)
      end
    end

    context "combined statistics" do
      before do
        book1 = Book.create!(user: user1, author: author1, title: "Book 1", status: "finished", rating: 5)
        book2 = Book.create!(user: user1, author: author1, title: "Book 2", status: "reading", rating: 4)
        book1.reading_sessions.create!(minutes: 30, date: Date.today)
        book2.reading_sessions.create!(minutes: 20, date: Date.today)
      end

      it "returns all statistics together" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        
        # Existing stats
        expect(body["total_books"]).to eq(2)
        expect(body["total_finished"]).to eq(1)
        expect(body["total_minutes"]).to eq(50)
        
        # Status breakdown
        expect(body["to_read_count"]).to eq(0)
        expect(body["reading_count"]).to eq(1)
        expect(body["finished_count"]).to eq(1)
        
        # Rating analytics
        expect(body["average_rating"]).to eq(4.5)
        expect(body["total_rated_books"]).to eq(2)
        expect(body["rating_distribution"]).to be_a(Hash)
        
        # Reading session analytics
        expect(body["total_reading_sessions"]).to eq(2)
        expect(body["average_session_minutes"]).to eq(25.0)
        expect(body["books_with_sessions"]).to eq(2)
      end
    end

    context "user_id filtering" do
      before do
        Book.create!(user: user1, author: author1, title: "User1 Book", status: "finished", rating: 5)
        Book.create!(user: user2, author: author1, title: "User2 Book", status: "reading", rating: 4)
        book1 = Book.find_by(title: "User1 Book")
        book1.reading_sessions.create!(minutes: 30, date: Date.today)
      end

      it "filters all new statistics by user_id parameter" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        
        expect(body["total_books"]).to eq(1)
        expect(body["to_read_count"]).to eq(0)
        expect(body["reading_count"]).to eq(0)
        expect(body["finished_count"]).to eq(1)
        expect(body["average_rating"]).to eq(5.0)
        expect(body["total_rated_books"]).to eq(1)
        expect(body["total_reading_sessions"]).to eq(1)
        expect(body["books_with_sessions"]).to eq(1)
      end

      it "returns different stats for different users" do
        get "/stats?user_id=#{user2.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        
        expect(body["total_books"]).to eq(1)
        expect(body["reading_count"]).to eq(1)
        expect(body["finished_count"]).to eq(0)
        expect(body["average_rating"]).to eq(4.0)
        expect(body["total_reading_sessions"]).to eq(0)
        expect(body["books_with_sessions"]).to eq(0)
      end
    end

    context "edge cases" do
      it "handles empty database gracefully (all counts are 0, averages are null)" do
        Book.destroy_all
        ReadingSession.destroy_all
        get "/stats"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        
        expect(body["total_books"]).to eq(0)
        expect(body["to_read_count"]).to eq(0)
        expect(body["reading_count"]).to eq(0)
        expect(body["finished_count"]).to eq(0)
        expect(body["total_minutes"]).to eq(0)
        expect(body["average_rating"]).to be_nil
        expect(body["total_rated_books"]).to eq(0)
        expect(body["rating_distribution"]["1"]).to eq(0)
        expect(body["rating_distribution"]["5"]).to eq(0)
        expect(body["total_reading_sessions"]).to eq(0)
        expect(body["average_session_minutes"]).to be_nil
        expect(body["books_with_sessions"]).to eq(0)
      end

      it "handles user with no books" do
        empty_user = User.create!(email: "empty@ex.com", name: "Empty")
        get "/stats?user_id=#{empty_user.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        
        expect(body["total_books"]).to eq(0)
        expect(body["to_read_count"]).to eq(0)
        expect(body["reading_count"]).to eq(0)
        expect(body["finished_count"]).to eq(0)
        expect(body["average_rating"]).to be_nil
        expect(body["total_rated_books"]).to eq(0)
        expect(body["total_reading_sessions"]).to eq(0)
        expect(body["average_session_minutes"]).to be_nil
        expect(body["books_with_sessions"]).to eq(0)
      end
    end

    context "backward compatibility" do
      before do
        Book.create!(user: user1, author: author1, title: "Book 1", status: "finished")
        Book.create!(user: user1, author: author1, title: "Book 2", status: "reading")
      end

      it "maintains existing response fields unchanged" do
        get "/stats?user_id=#{user1.id}"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        
        expect(body).to have_key("total_books")
        expect(body).to have_key("total_finished")
        expect(body).to have_key("total_minutes")
        expect(body["total_books"]).to eq(2)
        expect(body["total_finished"]).to eq(1)
      end

      it "existing stats still work without user_id parameter" do
        get "/stats"
        expect(last_response).to be_ok
        body = JSON.parse(last_response.body)
        
        expect(body["total_books"]).to be >= 0
        expect(body["total_finished"]).to be >= 0
        expect(body["total_minutes"]).to be >= 0
        expect(body).to have_key("to_read_count")
        expect(body).to have_key("reading_count")
        expect(body).to have_key("finished_count")
      end
    end
  end
end

