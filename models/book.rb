class Book < ActiveRecord::Base
  STATUSES = %w[to_read reading finished].freeze

  belongs_to :user
  belongs_to :author

  has_many :book_tags, dependent: :destroy
  has_many :tags, through: :book_tags
  has_many :reviews, dependent: :destroy
  has_many :reading_sessions, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  def total_minutes
    reading_sessions.sum(:minutes)
  end
end


