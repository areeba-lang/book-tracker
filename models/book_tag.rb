class BookTag < ActiveRecord::Base
  belongs_to :book
  belongs_to :tag

  validates :book_id, uniqueness: { scope: :tag_id }
end


