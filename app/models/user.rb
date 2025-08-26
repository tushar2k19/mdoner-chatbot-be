class User < ApplicationRecord
  # Enable secure password functionality (uses bcrypt)
  has_secure_password
  
  # Relationships
  has_many :conversations, dependent: :destroy
  
  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, allow_nil: true
  
  # Normalize email to lowercase before saving
  before_save { self.email = email.downcase }
  
  # Instance methods
  def full_name
    email.split('@').first.humanize
  end
end