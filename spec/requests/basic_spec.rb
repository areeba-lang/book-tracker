require "spec_helper"

RSpec.describe "Basic endpoints" do
  it "root returns name and version" do
    get "/"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["name"]).to eq("personal_book_tracker")
  end

  it "creates user and author" do
    post "/users", { name: "N", email: "n@n.com" }.to_json, { "CONTENT_TYPE" => "application/json" }
    expect(last_response.status).to eq(201)
    post "/authors", { name: "A" }.to_json, { "CONTENT_TYPE" => "application/json" }
    expect(last_response.status).to eq(201)
  end
end


