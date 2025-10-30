# Simple seed data to make the API useful right away

u = User.find_or_create_by!(email: "demo@example.com") do |x|
  x.name = "Demo User"
end

rowling = Author.find_or_create_by!(name: "J. K. Rowling")
martin  = Author.find_or_create_by!(name: "George R. R. Martin")

hp = Book.find_or_create_by!(title: "Harry Potter and the Sorcerer's Stone", user: u, author: rowling) do |b|
  b.status = "reading"
  b.rating = 5
end

got = Book.find_or_create_by!(title: "A Game of Thrones", user: u, author: martin) do |b|
  b.status = "to_read"
  b.rating = 0
end

fantasy = Tag.find_or_create_by!(name: "fantasy")
ya      = Tag.find_or_create_by!(name: "ya")

BookTag.find_or_create_by!(book: hp, tag: fantasy)
BookTag.find_or_create_by!(book: hp, tag: ya)

Review.find_or_create_by!(book: hp, body: "Magical start to a classic series.") do |r|
  r.rating = 5
end

ReadingSession.find_or_create_by!(book: hp, date: Date.today, minutes: 45)

puts "Seeded demo data. User email: demo@example.com"


