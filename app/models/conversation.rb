class Conversation < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :messages, dependent: :destroy

  # Validations
  validates :user_id, presence: true
  validates :openai_thread_id, presence: true, uniqueness: true
  validates :title, length: { maximum: 255 }, allow_nil: true

  # Enums
  enum status: { active: 'active', archived: 'archived', deleted: 'deleted' }

  # Callbacks
  before_validation :set_defaults
  before_save :normalize_title
  after_create :create_openai_thread
  after_update :update_openai_thread, if: :saved_change_to_title?

  # Scopes
  scope :recent, -> { order(updated_at: :desc) }
  scope :active, -> { where(status: 'active') }
  scope :archived, -> { where(status: 'archived') }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :with_messages, -> { includes(:messages) }

  # Instance methods
  def display_title
    title.presence || "Conversation #{id}"
  end

  def message_count
    messages.count
  end

  def last_message
    messages.order(created_at: :desc).first
  end

  def last_message_at
    last_message&.created_at || created_at
  end

  def first_message
    messages.order(created_at: :asc).first
  end

  def has_messages?
    messages.exists?
  end

  def empty?
    messages.empty?
  end

  def user_messages
    messages.where(role: 'user')
  end

  def assistant_messages
    messages.where(role: 'assistant')
  end

  def dpr_messages
    messages.where(source: 'dpr')
  end

  def web_messages
    messages.where(source: 'web')
  end

  def archive!
    update!(status: 'archived')
  end

  def unarchive!
    update!(status: 'active')
  end

  def soft_delete!
    update!(status: 'deleted')
  end

  def restore!
    update!(status: 'active')
  end

  def permanently_delete!
    # This would also delete the OpenAI thread
    destroy!
  end

  def can_add_message?
    active? && !deleted?
  end

  def needs_consent?
    last_message&.needs_consent? || false
  end

  def last_web_summary
    web_messages.last&.content_summary
  end

  # Message creation helpers
  def add_user_message(content)
    return false unless can_add_message?
    
    messages.create!(
      role: 'user',
      content: content,
      source: 'dpr'
    )
  end

  def add_assistant_message(content_data)
    return false unless can_add_message?
    
    messages.create!(
      role: 'assistant',
      content: content_data.is_a?(String) ? content_data : content_data.to_json,
      source: content_data.is_a?(Hash) && content_data[:needs_consent] ? 'web' : 'dpr'
    )
  end

  # Statistics
  def statistics
    {
      total_messages: message_count,
      user_messages: user_messages.count,
      assistant_messages: assistant_messages.count,
      dpr_messages: dpr_messages.count,
      web_messages: web_messages.count,
      created_at: created_at,
      last_activity: last_message_at
    }
  end

  # Class methods
  def self.create_for_user(user, title: nil)
    transaction do
      conversation = create!(
        user: user,
        title: title
      )
      conversation
    end
  end

  def self.find_by_openai_thread_id(thread_id)
    find_by(openai_thread_id: thread_id)
  end

  def self.recent_for_user(user_id, limit: 20)
    for_user(user_id).recent.limit(limit)
  end

  def self.search_by_title(query, user_id: nil)
    scope = where("title ILIKE ?", "%#{query}%")
    scope = scope.for_user(user_id) if user_id
    scope
  end

  def self.statistics_for_user(user_id)
    conversations = for_user(user_id)
    {
      total_conversations: conversations.count,
      active_conversations: conversations.active.count,
      archived_conversations: conversations.archived.count,
      total_messages: conversations.joins(:messages).count,
      last_activity: conversations.maximum(:updated_at)
    }
  end

  # OpenAI integration methods
  def create_openai_thread
    # This would be implemented in a service
    # For now, generate a placeholder thread ID
    self.openai_thread_id ||= "thread_#{SecureRandom.hex(12)}"
  end

  def update_openai_thread
    # This would update the thread metadata in OpenAI
    # Implementation would go here
  end

  def delete_openai_thread
    # This would delete the thread from OpenAI
    # Implementation would go here
  end

  private

  def set_defaults
    self.status ||= 'active'
  end

  def normalize_title
    self.title = title&.strip
  end
end
