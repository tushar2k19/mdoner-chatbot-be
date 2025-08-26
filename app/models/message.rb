class Message < ApplicationRecord
  # Relationships
  belongs_to :conversation
  
  # Validations
  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true
  
  # Enums for better role handling
  enum role: { user: 'user', assistant: 'assistant' }
  
  # Scopes
  scope :chronological, -> { order(:created_at) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  # Instance methods
  def has_citations?
    citations_json.present? && citations_json.any?
  end
  
  def citation_documents
    return [] unless has_citations?
    citations_json.map { |citation| citation['document'] }.uniq
  end
  
  def from_user?
    role == 'user'
  end
  
  def from_assistant?
    role == 'assistant'
  end
end