require "spec_helper"

RSpec.describe BookService do
  let(:user) { User.create!(email: "svc@example.com", name: "Svc") }

  it "creates a book with a new author" do
    book = described_class.new.create_with_author(user_id: user.id, title: "T", author_name: "New Author")
    expect(book).to be_persisted
    expect(book.author.name).to eq("New Author")
  end

  it "returns stats for a user" do
    service = described_class.new
    service.create_with_author(user_id: user.id, title: "A", author_name: "X", status: "finished")
    service.create_with_author(user_id: user.id, title: "B", author_name: "Y", status: "reading")
    Book.first.reading_sessions.create!(minutes: 30, date: Date.today)
    stats = service.stats(user_id: user.id)
    expect(stats[:total_books]).to eq(2)
    expect(stats[:total_finished]).to eq(1)
    expect(stats[:total_minutes]).to eq(30)
  end
end


