class User < ActiveRecord::Base
  has_many :books, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end


