class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :conversations, dependent: :destroy
  has_many :messages, through: :conversations, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  
  # Enums
  enum role: { user: 0, admin: 1 }

  # Callbacks
  before_save { self.email = email.downcase }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.presence || email.split('@').first.humanize
  end

  def admin?
    role == 'admin'
  end

  def user?
    role == 'user'
  end

  # Class methods
  def self.find_by_email(email)
    find_by(email: email&.downcase)
  end


  # Statistics methods
  def conversation_count
    conversations.count
  end

  def message_count
    messages.count
  end

  def last_activity_at
    conversations.maximum(:updated_at) || created_at
  end

  # Authentication helpers
  # def generate_jwt_token
  #   payload = {
  #     user_id: id,
  #     email: email,
  #     exp: 24.hours.from_now.to_i
  #   }
  #   JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  # end

  # def self.decode_jwt_token(token)
  #   decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
  #   decoded.first
  # rescue JWT::DecodeError, JWT::ExpiredSignature
  #   nil
  # end
end