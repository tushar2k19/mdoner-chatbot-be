class Message < ApplicationRecord
  # Associations
  belongs_to :conversation

  # Validations
  validates :conversation_id, presence: true
  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true
  validates :source, presence: true, inclusion: { in: %w[dpr web] }
  validates :openai_message_id, uniqueness: true, allow_nil: true
  validates :openai_run_id, presence: false

  # Enums
  enum role: { user: 'user', assistant: 'assistant' }
  enum source: { dpr: 'dpr', web: 'web' }

  # Callbacks
  before_validation :set_defaults
  before_save :normalize_content
  after_save :update_conversation_timestamp

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :by_role, ->(role) { where(role: role) }
  scope :by_source, ->(source) { where(source: source) }
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :dpr_messages, -> { where(source: 'dpr') }
  scope :web_messages, -> { where(source: 'web') }

  # Instance methods
  def user_message?
    role == 'user'
  end

  def assistant_message?
    role == 'assistant'
  end

  def dpr_message?
    source == 'dpr'
  end

  def web_message?
    source == 'web'
  end

  # Content parsing methods (for assistant messages)
  def content_data
    return content if user_message?
    
    begin
      JSON.parse(content)
    rescue JSON::ParserError
      { answer: content, citations: [], needs_consent: false }
    end
  end

  def answer
    return content if user_message?
    content_data['answer'] || ''
  end

  def citations
    return [] if user_message?
    content_data['citations'] || []
  end

  def needs_consent?
    return false if user_message?
    content_data['needs_consent'] || false
  end

  def consent_message
    return nil if user_message?
    content_data['message']
  end

  def has_citations?
    citations.any?
  end

  def citation_count
    citations.length
  end

  def content_summary(max_length: 100)
    text = user_message? ? content : answer
    return text if text.length <= max_length
    
    "#{text[0...max_length]}..."
  end

  # Content creation helpers
  def self.create_user_message(conversation, content)
    create!(
      conversation: conversation,
      role: 'user',
      content: content,
      source: 'dpr'
    )
  end

  def self.create_assistant_message(conversation, content_data)
    content = content_data.is_a?(String) ? content_data : content_data.to_json
    
    create!(
      conversation: conversation,
      role: 'assistant',
      content: content,
      source: determine_source(content_data)
    )
  end

  def self.create_dpr_response(conversation, answer, citations = [])
    content_data = {
      answer: answer,
      citations: citations,
      needs_consent: false
    }
    
    create_assistant_message(conversation, content_data)
  end

  def self.create_consent_request(conversation, message = "Result not found, do you wish to search the internet?")
    content_data = {
      answer: "",
      citations: [],
      needs_consent: true,
      message: message
    }
    
    create_assistant_message(conversation, content_data)
  end

  def self.create_web_response(conversation, answer, citations = [])
    content_data = {
      answer: answer,
      citations: citations,
      needs_consent: false
    }
    
    create!(
      conversation: conversation,
      role: 'assistant',
      content: content_data.to_json,
      source: 'web'
    )
  end

  # Search and filtering
  def self.search_content(query)
    where("content ILIKE ?", "%#{query}%")
  end

  def self.with_citations
    assistant_messages.where("content LIKE ?", '%"citations"%')
  end

  def self.needing_consent
    assistant_messages.where("content LIKE ?", '%"needs_consent":true%')
  end

  # Statistics
  def self.statistics_for_conversation(conversation_id)
    messages = where(conversation_id: conversation_id)
    {
      total_messages: messages.count,
      user_messages: messages.user_messages.count,
      assistant_messages: messages.assistant_messages.count,
      dpr_messages: messages.dpr_messages.count,
      web_messages: messages.web_messages.count,
      messages_with_citations: messages.with_citations.count,
      consent_requests: messages.needing_consent.count
    }
  end

  def self.statistics_for_user(user_id)
    messages = joins(:conversation).where(conversations: { user_id: user_id })
    {
      total_messages: messages.count,
      user_messages: messages.user_messages.count,
      assistant_messages: messages.assistant_messages.count,
      dpr_messages: messages.dpr_messages.count,
      web_messages: messages.web_messages.count,
      messages_with_citations: messages.with_citations.count,
      consent_requests: messages.needing_consent.count
    }
  end

  # OpenAI integration
  def self.find_by_openai_message_id(message_id)
    find_by(openai_message_id: message_id)
  end

  def self.find_by_openai_run_id(run_id)
    where(openai_run_id: run_id)
  end

  # Pagination helpers
  def self.paginated_for_conversation(conversation_id, page: 1, per_page: 50)
    where(conversation_id: conversation_id)
      .oldest_first
      .offset((page - 1) * per_page)
      .limit(per_page)
  end

  def self.before_message(message_id, limit: 50)
    message = find(message_id)
    where(conversation_id: message.conversation_id)
      .where("created_at < ?", message.created_at)
      .oldest_first
      .limit(limit)
  end

  def self.after_message(message_id, limit: 50)
    message = find(message_id)
    where(conversation_id: message.conversation_id)
      .where("created_at > ?", message.created_at)
      .oldest_first
      .limit(limit)
  end

  # Class methods
  def self.determine_source(content_data)
    return 'web' if content_data.is_a?(Hash) && content_data[:needs_consent]
    'dpr'
  end

  private

  def set_defaults
    self.source ||= 'dpr'
  end

  def normalize_content
    self.content = content&.strip
  end

  def update_conversation_timestamp
    conversation.touch if conversation.present?
  end
end




