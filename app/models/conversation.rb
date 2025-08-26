class Conversation < ApplicationRecord
  # Relationships
  belongs_to :user
  has_many :messages, dependent: :destroy
  has_many :external_search_logs, dependent: :destroy
  
  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :openai_thread_id, presence: true, uniqueness: true
  
  # Scopes
  scope :recent, -> { order(updated_at: :desc) }
  
  # Instance methods
  def message_count
    messages.count
  end
  
  def last_message_at
    messages.maximum(:created_at)
  end
end