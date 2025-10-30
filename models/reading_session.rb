class ReadingSession < ActiveRecord::Base
  belongs_to :book

  validates :minutes, numericality: { greater_than: 0 }
  validates :date, presence: true
end


