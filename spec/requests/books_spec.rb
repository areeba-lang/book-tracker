require "spec_helper"

RSpec.describe "Books API", type: :request do
  let!(:user) { User.create!(email: "req@example.com", name: "Req") }
  let!(:author) { Author.create!(name: "Author") }

  def json_headers
    { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
  end

  it "creates a book" do
    payload = { user_id: user.id, title: "Book One", author_name: "Author" }.to_json
    post "/books", payload, json_headers
    expect(last_response.status).to eq(201)
    body = JSON.parse(last_response.body)
    expect(body["title"]).to eq("Book One")
  end

  it "lists books" do
    Book.create!(user: user, author: author, title: "B1")
    get "/books"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["books"].size).to be >= 1
  end

  it "updates a book" do
    b = Book.create!(user: user, author: author, title: "B2")
    patch "/books/#{b.id}", { status: "reading" }.to_json, json_headers
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["status"]).to eq("reading")
  end

  it "adds tags to a book" do
    b = Book.create!(user: user, author: author, title: "B3")
    post "/books/#{b.id}/tags", { names: ["ruby", "api"] }.to_json, json_headers
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["tags"].map { |t| t["name"] }).to include("ruby", "api")
  end

  it "records a reading session" do
    b = Book.create!(user: user, author: author, title: "B4")
    post "/books/#{b.id}/reading_sessions", { minutes: 20, date: Date.today.to_s }.to_json, json_headers
    expect(last_response.status).to eq(201)
    body = JSON.parse(last_response.body)
    expect(body["total_minutes"]).to eq(20)
  end

  it "deletes a book" do
    b = Book.create!(user: user, author: author, title: "B5")
    delete "/books/#{b.id}"
    expect(last_response.status).to eq(204)
    expect(Book.find_by(id: b.id)).to be_nil
  end
end


