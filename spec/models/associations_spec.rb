require "spec_helper"

RSpec.describe "Model associations" do
  it "book belongs to user and author and has dependent children" do
    u = User.create!(email: "x@y.com")
    a = Author.create!(name: "N")
    b = Book.create!(user: u, author: a, title: "T")
    t = Tag.create!(name: "tag1")
    BookTag.create!(book: b, tag: t)
    b.reviews.create!(body: "Nice", rating: 4)
    b.reading_sessions.create!(minutes: 5, date: Date.today)
    expect(b.user).to eq(u)
    expect(b.author).to eq(a)
    expect(b.tags.count).to eq(1)
    expect(b.reviews.count).to eq(1)
    expect(b.reading_sessions.count).to eq(1)
    b.destroy
    expect(Review.count).to eq(0)
    expect(ReadingSession.count).to eq(0)
    expect(BookTag.count).to eq(0)
  end
end


