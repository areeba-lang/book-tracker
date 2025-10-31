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

  # Helper to build a filtered/sorted/paginated query for books.
  # Options (all optional):
  # - user_id: filter by user
  # - status: filter by status
  # - author_q: partial match on author name
  # - tag: filter by tag name
  # - q: general search query (searches title and author name)
  # - sort: one of "title", "created_at" (defaults to created_at)
  # - dir: "asc" or "desc" (defaults to desc)
  # - page: integer >= 1 (defaults to 1)
  # - per_page: integer 1..100 (defaults to 20)
  def query_books(options = {})
    scope = Book.includes(:author, :tags, :reviews, :reading_sessions)
    scope = scope.where(user_id: options[:user_id]) if options[:user_id]
    scope = scope.where(status: options[:status]) if options[:status]
    if options[:author_q]
      scope = scope.joins(:author).where("authors.name LIKE ?", "%#{options[:author_q]}%")
    end
    if options[:tag]
      scope = scope.joins(:tags).where("tags.name = ?", options[:tag])
    end
    if options[:q] && !options[:q].to_s.strip.empty?
      search_term = options[:q].to_s.strip
      scope = scope.joins(:author).where(
        "books.title LIKE ? OR authors.name LIKE ?",
        "%#{search_term}%",
        "%#{search_term}%"
      )
    end

    sort = %w[title created_at].include?(options[:sort].to_s) ? options[:sort].to_s : "created_at"
    dir = options[:dir].to_s.downcase == "asc" ? :asc : :desc
    scope = scope.order(sort => dir)

    page = options[:page].to_i
    page = 1 if page <= 0
    per_page = options[:per_page].to_i
    per_page = 20 if per_page <= 0
    per_page = 100 if per_page > 100

    total = scope.count
    records = scope.offset((page - 1) * per_page).limit(per_page)

    {
      records: records,
      meta: {
        page: page,
        per_page: per_page,
        total: total
      }
    }
  end
end


