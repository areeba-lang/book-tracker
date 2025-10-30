require "spec_helper"

RSpec.describe "Authors/Tags listing" do
  it "lists authors and filters by q" do
    Author.create!(name: "Isaac Asimov")
    Author.create!(name: "Frank Herbert")
    get "/authors"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["authors"].size).to be >= 2
    get "/authors?q=Isaac"
    body = JSON.parse(last_response.body)
    expect(body["authors"].map { |a| a["name"] }).to include("Isaac Asimov")
  end

  it "lists tags and filters by q" do
    Tag.create!(name: "sci-fi")
    Tag.create!(name: "classic")
    get "/tags"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["tags"].size).to be >= 2
    get "/tags?q=clas"
    body = JSON.parse(last_response.body)
    expect(body["tags"].map { |t| t["name"] }).to include("classic")
  end
end


