class User < ApplicationRecord
  has_secure_password

# has_many :conversations, dependent: :destroy
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  
  # Normalize email to lowercase before saving
  before_save { self.email = email.downcase }
  enum role: { user: 0, admin: 1 }

  
  def full_name
    email.split('@').first.humanize
  end
end