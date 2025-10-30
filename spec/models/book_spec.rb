require "spec_helper"

RSpec.describe Book, type: :model do
  let(:user) { User.create!(email: "a@b.com", name: "A") }
  let(:author) { Author.create!(name: "Author") }

  it "validates presence of title" do
    b = Book.new(user: user, author: author, title: "")
    expect(b.valid?).to be false
    expect(b.errors[:title]).not_to be_empty
  end

  it "has default status to_read" do
    b = Book.create!(user: user, author: author, title: "T")
    expect(b.status).to eq("to_read")
  end

  it "computes total minutes" do
    b = Book.create!(user: user, author: author, title: "T")
    b.reading_sessions.create!(minutes: 10, date: Date.today)
    b.reading_sessions.create!(minutes: 25, date: Date.today)
    expect(b.total_minutes).to eq(35)
  end
end


