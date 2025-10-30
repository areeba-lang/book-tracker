# A tiny validator to keep controllers thin and error messages friendly
class BookValidator
  def self.validate_create(payload)
    errors = []
    errors << "user_id is required" unless payload.key?("user_id")
    errors << "title is required" if payload["title"].to_s.strip.empty?
    errors << "author_name is required" if payload["author_name"].to_s.strip.empty?
    if payload.key?("rating")
      r = payload["rating"].to_i
      errors << "rating must be between 0 and 5" unless (0..5).include?(r)
    end
    if payload.key?("status")
      s = payload["status"].to_s
      errors << "status must be one of #{Book::STATUSES.join(', ')}" unless Book::STATUSES.include?(s)
    end
    errors
  end
end


