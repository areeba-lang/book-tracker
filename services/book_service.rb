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

  def create_bulk(books_array)
    results = []
    successful = 0
    failed = 0

    books_array.each_with_index do |book_data, index|
      # Validate using existing validator
      errors = BookValidator.validate_create(book_data)
      
      if errors.empty?
        begin
          book = create_with_author(
            user_id: book_data["user_id"],
            title: book_data["title"],
            author_name: book_data["author_name"],
            status: book_data["status"],
            rating: book_data["rating"]
          )
          results << {
            success: true,
            book: BookSerializer.new(book).as_json
          }
          successful += 1
        rescue Error => e
          results << {
            success: false,
            error: e.message,
            index: index
          }
          failed += 1
        end
      else
        results << {
          success: false,
          error: errors.join(", "),
          index: index
        }
        failed += 1
      end
    end

    {
      results: results,
      meta: {
        total: books_array.length,
        successful: successful,
        failed: failed
      }
    }
  end

  def stats(user_id: nil)
    scope = Book.all
    scope = scope.where(user_id: user_id) if user_id
    
    # Existing stats (backward compatible)
    total_books = scope.count
    total_finished = scope.where(status: "finished").count
    total_minutes = ReadingSession.joins(:book).merge(scope).sum(:minutes) || 0
    
    # Status breakdown
    to_read_count = scope.where(status: "to_read").count
    reading_count = scope.where(status: "reading").count
    finished_count = scope.where(status: "finished").count
    
    # Rating analytics
    rated_scope = scope.where("rating > 0")
    total_rated_books = rated_scope.count
    average_rating = total_rated_books > 0 ? rated_scope.average(:rating).to_f.round(2) : nil
    
    # Rating distribution (1-5)
    rating_dist = rated_scope.group(:rating).count
    rating_distribution = {
      "1" => rating_dist[1] || 0,
      "2" => rating_dist[2] || 0,
      "3" => rating_dist[3] || 0,
      "4" => rating_dist[4] || 0,
      "5" => rating_dist[5] || 0
    }
    
    # Reading session analytics
    sessions_scope = ReadingSession.joins(:book).merge(scope)
    total_reading_sessions = sessions_scope.count
    avg_session_minutes = total_reading_sessions > 0 ? (sessions_scope.average(:minutes).to_f.round(2)) : nil
    books_with_sessions = scope.joins(:reading_sessions).distinct.count
    
    {
      # Existing stats (backward compatible)
      total_books: total_books,
      total_finished: finished_count,
      total_minutes: total_minutes,
      
      # Status breakdown
      to_read_count: to_read_count,
      reading_count: reading_count,
      finished_count: finished_count,
      
      # Rating analytics
      average_rating: average_rating,
      total_rated_books: total_rated_books,
      rating_distribution: rating_distribution,
      
      # Reading session analytics
      total_reading_sessions: total_reading_sessions,
      average_session_minutes: avg_session_minutes,
      books_with_sessions: books_with_sessions
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


