class Document < ApplicationRecord
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :original_filename, presence: true, length: { maximum: 255 }
  validates :s3_key, presence: true, length: { maximum: 500 }
  validates :s3_bucket, presence: true, length: { maximum: 100 }
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :mime_type, presence: true, length: { maximum: 100 }
  validates :openai_file_id, uniqueness: true, allow_nil: true
  validates :sha256_hash, length: { is: 64 }, allow_nil: true

  # Enums
  enum status: { inactive: 'inactive', active: 'active', processing: 'processing', error: 'error' }

  # Callbacks
  before_validation :set_defaults
  before_save :normalize_filename
  after_save :update_conversation_timestamps, if: :saved_change_to_status?

  # Instance methods
  def display_name
    name.presence || original_filename
  end

  def file_size_mb
    (file_size / 1024.0 / 1024.0).round(2)
  end

  def file_size_kb
    (file_size / 1024.0).round(2)
  end

  def pdf?
    mime_type == 'application/pdf'
  end

  def active?
    status == 'active'
  end

  def processing?
    status == 'processing'
  end

  def error?
    status == 'error'
  end

  def s3_url_with_expiry(expires_in: 1.hour)
    return s3_url if s3_url.present?
    
    # Generate pre-signed URL if s3_url is not set
    generate_presigned_url(expires_in)
  end

  def generate_presigned_url(expires_in = 1.hour)
    # This would be implemented with AWS SDK
    # For now, return a placeholder
    "https://#{s3_bucket}.s3.#{s3_region}.amazonaws.com/#{s3_key}?expires=#{expires_in.to_i}"
  end

  def openai_ready?
    openai_file_id.present? && active?
  end

  def needs_openai_upload?
    openai_file_id.blank? && active?
  end

  def mark_as_processing!
    update!(status: 'processing')
  end

  def mark_as_active!
    update!(status: 'active')
  end

  def mark_as_error!(error_message = nil)
    update!(status: 'error')
    # Could add error logging here
  end

  # Class methods
  def self.active
    where(status: 'active')
  end

  def self.by_filename(filename)
    where(original_filename: filename)
  end

  def self.by_openai_file_id(file_id)
    find_by(openai_file_id: file_id)
  end

  def self.available_for_chat
    active.where.not(openai_file_id: nil)
  end

  def self.total_size
    sum(:file_size)
  end

  def self.total_size_mb
    (total_size / 1024.0 / 1024.0).round(2)
  end

  def self.count_by_status
    group(:status).count
  end

  # Search methods
  def self.search(query)
    where("name ILIKE ? OR original_filename ILIKE ?", "%#{query}%", "%#{query}%")
  end

  # Statistics
  def self.statistics
    {
      total_count: count,
      active_count: active.count,
      total_size_mb: total_size_mb,
      by_status: count_by_status
    }
  end

  private

  def set_defaults
    self.mime_type ||= 'application/pdf'
    self.s3_region ||= 'us-east-1'
    self.status ||= 'inactive'
  end

  def normalize_filename
    self.original_filename = original_filename.strip if original_filename.present?
    self.name = name.strip if name.present?
  end

  def update_conversation_timestamps
    # This could be used to invalidate caches or trigger updates
    # when document status changes
  end
end


