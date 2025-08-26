class Document < ApplicationRecord
  # Validations
  validates :original_filename, presence: true
  validates :openai_file_id, presence: true, uniqueness: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :sha256_hash, presence: true, uniqueness: true
  validates :ocr_status, inclusion: { in: %w[pending completed failed] }
  
  # Enums for better status handling
  enum ocr_status: { pending: 'pending', completed: 'completed', failed: 'failed' }
  
  # Scopes for easy querying
  scope :available, -> { where(ocr_status: 'completed') }
  scope :text_based, -> { where(ocr_status: 'completed') }
  
  # Instance methods
  def display_name
    original_filename.gsub('.pdf', '').humanize
  end
  
  def file_size_mb
    (file_size.to_f / 1024 / 1024).round(2)
  end
  
  def ready_for_search?
    ocr_status == 'completed' && openai_file_id.present?
  end
end