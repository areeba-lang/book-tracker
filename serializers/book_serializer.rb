class BookSerializer
  def initialize(book)
    @book = book
  end

  def as_json
    {
      id: @book.id,
      title: @book.title,
      status: @book.status,
      rating: @book.rating,
      total_minutes: @book.total_minutes,
      user: @book.user && { id: @book.user.id, name: @book.user.name, email: @book.user.email },
      author: { id: @book.author.id, name: @book.author.name },
      tags: @book.tags.order(:name).map { |t| { id: t.id, name: t.name } },
      reviews: @book.reviews.order(created_at: :desc).map { |r| { id: r.id, body: r.body, rating: r.rating } },
      reading_sessions: @book.reading_sessions.order(date: :desc).map { |s| { id: s.id, minutes: s.minutes, date: s.date } },
      created_at: @book.created_at,
      updated_at: @book.updated_at
    }
  end
end


