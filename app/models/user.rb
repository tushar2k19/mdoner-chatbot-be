class User < ApplicationRecord
  has_secure_password

  enum role: { user: 0, admin: 1 }

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
end


