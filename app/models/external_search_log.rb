class ExternalSearchLog < ApplicationRecord
  # Relationships
  belongs_to :conversation
  
  # Validations
  validates :provider, presence: true, inclusion: { in: %w[tavily perplexity] }
  validates :query, presence: true, length: { minimum: 1, maximum: 1000 }
  validates :results_json, presence: true
  
  # Enums for provider handling
  enum provider: { tavily: 'tavily', perplexity: 'perplexity' }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  
  # Instance methods
  def has_results?
    results_json.present? && results_json.any?
  end
  
  def result_count
    return 0 unless has_results?
    results_json.is_a?(Array) ? results_json.size : results_json.dig('results')&.size || 0
  end
  
  def search_summary
    "#{provider.humanize} search for '#{query.truncate(50)}' (#{result_count} results)"
  end
end