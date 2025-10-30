class BookService
  class Error < StandardError; end

  def create_with_author(user_id:, title:, author_name:, status: nil, rating: nil)
    raise Error, "user_id required" unless user_id
    raise Error, "title required" if title.to_s.strip.empty?
    raise Error, "author_name required" if author_name.to_s.strip.empty?

    user = User.find_by(id: user_id)
    raise Error, "User not found" unless user

    author = Author.find_or_create_by!(name: author_name.strip)
    attrs = { user: user, author: author, title: title.strip }
    attrs[:status] = status if status
    attrs[:rating] = rating if !rating.nil?
    Book.create!(**attrs)
  end

  def stats(user_id: nil)
    scope = Book.all
    scope = scope.where(user_id: user_id) if user_id
    {
      total_books: scope.count,
      total_finished: scope.where(status: "finished").count,
      total_minutes: ReadingSession.joins(:book).merge(scope).sum(:minutes)
    }
  end
end


