require "spec_helper"

RSpec.describe "Books filters, sorting, pagination" do
  let!(:user) { User.create!(email: "req2@example.com", name: "Req2") }
  let!(:author1) { Author.create!(name: "Author One") }
  let!(:author2) { Author.create!(name: "Author Two") }

  before do
    b1 = Book.create!(user: user, author: author1, title: "Alpha", status: "reading")
    b2 = Book.create!(user: user, author: author2, title: "Beta", status: "to_read")
    t1 = Tag.create!(name: "sci-fi")
    t2 = Tag.create!(name: "classic")
    BookTag.create!(book: b1, tag: t1)
    BookTag.create!(book: b2, tag: t2)
  end

  it "filters by tag" do
    get "/books?tag=sci-fi"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["books"].map { |b| b["title"] }).to include("Alpha")
    expect(body["books"].map { |b| b["title"] }).not_to include("Beta")
  end

  it "sorts by title asc" do
    get "/books?sort=title&dir=asc"
    body = JSON.parse(last_response.body)
    titles = body["books"].map { |b| b["title"] }
    expect(titles).to eq(titles.sort)
  end

  it "paginates with meta" do
    get "/books?page=1&per_page=1&sort=title&dir=asc"
    body = JSON.parse(last_response.body)
    expect(body["books"].size).to eq(1)
    expect(body["meta"]).to include("page", "per_page", "total")
  end
end


