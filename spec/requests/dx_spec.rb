require "spec_helper"

RSpec.describe "DX endpoints" do
  it "returns health ok" do
    get "/health"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["status"]).to eq("ok")
  end

  it "returns version" do
    get "/version"
    expect(last_response).to be_ok
    body = JSON.parse(last_response.body)
    expect(body["version"]).to eq("1.0.0")
  end
end


