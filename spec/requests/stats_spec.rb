require "spec_helper"

RSpec.describe "Stats endpoint" do
  let!(:user) { User.create!(email: "stats@ex.com") }
  let!(:author) { Author.create!(name: "Auth") }

  it "returns overall stats" do
    b1 = Book.create!(user: user, author: author, title: "X", status: "finished")
    b2 = Book.create!(user: user, author: author, title: "Y", status: "reading")
    b1.reading_sessions.create!(minutes: 25, date: Date.today)
    get "/stats"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["total_books"]).to be >= 2
    expect(body["total_finished"]).to be >= 1
    expect(body["total_minutes"]).to be >= 25
  end
end


