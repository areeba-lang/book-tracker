require "sinatra"
require "sinatra/json"
require "sinatra/namespace"
require "sinatra/activerecord"
require_relative "config/database"

# Load models, services, serializers, validators
Dir[File.join(__dir__, "models", "**", "*.rb")].sort.each { |f| require f }
Dir[File.join(__dir__, "services", "**", "*.rb")].sort.each { |f| require f }
Dir[File.join(__dir__, "serializers", "**", "*.rb")].sort.each { |f| require f }
Dir[File.join(__dir__, "validators", "**", "*.rb")].sort.each { |f| require f }

# Note: Migrations are run via Rake tasks (db:migrate). No auto-migrate on boot.

before do
  content_type :json
end

helpers do
  def json_params
    request.body.rewind
    body = request.body.read
    body.empty? ? {} : JSON.parse(body)
  rescue JSON::ParserError
    halt 400, { error: "Invalid JSON" }.to_json
  end

  def serialize_book(book)
    BookSerializer.new(book).as_json
  end
end

get "/" do
  { name: "personal_book_tracker", version: "1.0.0" }.to_json
end

# DX endpoints
get "/health" do
  { status: "ok" }.to_json
end

get "/version" do
  { version: "1.0.0" }.to_json
end

post "/users" do
  user = User.new(json_params.slice("name", "email"))
  if user.save
    status 201
    user.attributes.slice("id", "name", "email").to_json
  else
    status 422
    { error: user.errors.full_messages }.to_json
  end
end

post "/authors" do
  author = Author.new(json_params.slice("name"))
  if author.save
    status 201
    author.attributes.slice("id", "name").to_json
  else
    status 422
    { error: author.errors.full_messages }.to_json
  end
end

post "/books" do
  payload = json_params
  errors = BookValidator.validate_create(payload)
  halt 422, { error: errors }.to_json unless errors.empty?

  service = BookService.new
  book = service.create_with_author(
    user_id: payload["user_id"],
    title: payload["title"],
    author_name: payload["author_name"],
    status: payload["status"],
    rating: payload["rating"]
  )

  status 201
  serialize_book(book).to_json
rescue BookService::Error => e
  status 422
  { error: e.message }.to_json
end

get "/books" do
  service = BookService.new
  result = service.query_books(
    user_id: params["user_id"],
    status: params["status"],
    author_q: params["author"],
    tag: params["tag"],
    sort: params["sort"],
    dir: params["dir"],
    page: params["page"],
    per_page: params["per_page"]
  )
  {
    books: result[:records].map { |b| serialize_book(b) },
    meta: result[:meta]
  }.to_json
end

get "/books/:id" do
  book = Book.includes(:author, :tags, :reviews, :reading_sessions).find_by(id: params[:id])
  halt 404, { error: "Not found" }.to_json unless book
  serialize_book(book).to_json
end

# Authors listing with optional name filter (?q=)
get "/authors" do
  scope = Author.all
  scope = scope.where("name LIKE ?", "%#{params["q"]}%") if params["q"]
  { authors: scope.order(:name).map { |a| { id: a.id, name: a.name } } }.to_json
end

# Tags listing with optional name filter (?q=)
get "/tags" do
  scope = Tag.all
  scope = scope.where("name LIKE ?", "%#{params["q"]}%") if params["q"]
  { tags: scope.order(:name).map { |t| { id: t.id, name: t.name } } }.to_json
end

patch "/books/:id" do
  book = Book.find_by(id: params[:id])
  halt 404, { error: "Not found" }.to_json unless book

  up = json_params.slice("status", "rating", "title")
  if book.update(up)
    serialize_book(book.reload).to_json
  else
    status 422
    { error: book.errors.full_messages }.to_json
  end
end

delete "/books/:id" do
  book = Book.find_by(id: params[:id])
  halt 404, { error: "Not found" }.to_json unless book
  book.destroy
  status 204
  ""
end

post "/books/:id/tags" do
  book = Book.find_by(id: params[:id])
  halt 404, { error: "Not found" }.to_json unless book
  names = Array(json_params["names"]).map(&:to_s).map(&:strip).reject(&:empty?)
  halt 422, { error: "names must be a non-empty array" }.to_json if names.empty?
  names.each do |name|
    tag = Tag.find_or_create_by!(name: name)
    BookTag.find_or_create_by!(book: book, tag: tag)
  end
  serialize_book(book.reload).to_json
end

post "/books/:id/reviews" do
  book = Book.find_by(id: params[:id])
  halt 404, { error: "Not found" }.to_json unless book
  review = book.reviews.new(json_params.slice("body", "rating"))
  if review.save
    status 201
    serialize_book(book.reload).to_json
  else
    status 422
    { error: review.errors.full_messages }.to_json
  end
end

post "/books/:id/reading_sessions" do
  book = Book.find_by(id: params[:id])
  halt 404, { error: "Not found" }.to_json unless book
  minutes = json_params["minutes"].to_i
  date = if json_params["date"]
    begin
      Date.parse(json_params["date"])
    rescue ArgumentError
      Date.today
    end
  else
    Date.today
  end
  session = book.reading_sessions.new(minutes: minutes, date: date)
  if session.save
    status 201
    serialize_book(book.reload).to_json
  else
    status 422
    { error: session.errors.full_messages }.to_json
  end
end

get "/stats" do
  user_id = params["user_id"]
  stats = BookService.new.stats(user_id: user_id)
  stats.to_json
end

error ActiveRecord::RecordInvalid do |e|
  status 422
  { error: e.message }.to_json
end

error do
  status 500
  { error: env["sinatra.error"].message }.to_json
end


