require "csv"
require_relative "../serializers/book_serializer"

class ExportService
  class Error < StandardError; end

  def export_books(format:, user_id: nil, status: nil, tag: nil)
    format = format.to_s.downcase.strip
    raise Error, "format parameter is required" if format.empty?
    raise Error, "Invalid format. Must be 'json' or 'csv'" unless %w[json csv].include?(format)

    # Validate status if provided
    if status && !Book::STATUSES.include?(status.to_s)
      raise Error, "Invalid status. Must be one of: #{Book::STATUSES.join(', ')}"
    end

    # Build query scope with filters
    scope = Book.includes(:author, :tags, :reviews, :reading_sessions)
    scope = scope.where(user_id: user_id) if user_id
    scope = scope.where(status: status) if status
    if tag
      scope = scope.joins(:tags).where("tags.name = ?", tag)
    end
    scope = scope.order(created_at: :desc)

    books = scope.to_a
    total = books.length

    case format
    when "json"
      export_json(books, total)
    when "csv"
      export_csv(books, total)
    end
  end

  private

  def export_json(books, total)
    serialized_books = books.map { |book| BookSerializer.new(book).as_json }
    {
      books: serialized_books,
      meta: {
        total: total,
        format: "json",
        exported_at: Time.now.utc.iso8601
      }
    }
  end

  def export_csv(books, total)
    CSV.generate do |csv|
      # Headers
      csv << [
        "id", "title", "status", "rating", "total_minutes",
        "author_id", "author_name", "tags",
        "review_count", "average_review_rating",
        "reading_session_count",
        "created_at", "updated_at"
      ]

      # Data rows
      books.each do |book|
        tags_str = book.tags.order(:name).pluck(:name).join(", ")
        review_count = book.reviews.count
        avg_review_rating = if review_count > 0
          book.reviews.average(:rating).to_f.round(2)
        else
          0.0
        end
        session_count = book.reading_sessions.count

        csv << [
          book.id,
          book.title,
          book.status,
          book.rating,
          book.total_minutes,
          book.author.id,
          book.author.name,
          tags_str,
          review_count,
          avg_review_rating,
          session_count,
          book.created_at.iso8601,
          book.updated_at.iso8601
        ]
      end
    end
  end
end

