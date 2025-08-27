class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document, only: [:show, :pdf]

  # GET /api/documents
  # List all available documents for the user
  # Returns: documents array with metadata
  def index
    # TODO: Return all active documents
    # TODO: Include file_size, status, created_at
    # TODO: Filter by status (active only)
    # TODO: Order by name
  end

  # GET /api/documents/:id
  # Get single document details
  # Returns: document object with full metadata
  def show
    # TODO: Return document with all fields
    # TODO: Include S3 metadata
    # TODO: Check if document is active
  end

  # GET /api/documents/:id/pdf
  # Get pre-signed S3 URL for PDF viewing
  # Returns: S3 URL with expiration
  def pdf
    # TODO: Generate pre-signed S3 URL
    # TODO: Set appropriate expiration (1 hour)
    # TODO: Include document metadata
    # TODO: Handle S3 errors
  end

  # POST /api/documents/:id/refresh_s3_url
  # Refresh expired S3 URL
  # Returns: new S3 URL
  def refresh_s3_url
    # TODO: Generate new pre-signed URL
    # TODO: Update expiration time
  end

  # GET /api/documents/status
  # Get overall document system status
  # Returns: status summary
  def status
    # TODO: Return document count by status
    # TODO: Include OpenAI file status
    # TODO: Check S3 connectivity
  end

  # Admin endpoints (require admin role)
#   before_action :require_admin, only: [:create, :update, :destroy, :upload_to_openai]

#   # POST /api/admin/documents
#   # Create new document record (admin only)
#   # Params: name, original_filename, s3_key, s3_bucket, file_size, mime_type
#   # Returns: created document
#   def create
#     # TODO: Validate admin permissions
#     # TODO: Create document record
#     # TODO: Validate S3 file exists
#     # TODO: Generate SHA256 hash
#     # TODO: Handle validation errors
#   end

#   # PUT /api/admin/documents/:id
#   # Update document metadata (admin only)
#   # Params: name, status, metadata
#   # Returns: updated document
#   def update
#     # TODO: Validate admin permissions
#     # TODO: Update document fields
#     # TODO: Handle status changes
#     # TODO: Update OpenAI file if needed
#   end

#   # DELETE /api/admin/documents/:id
#   # Delete document (admin only)
#   # Returns: success message
#   def destroy
#     # TODO: Validate admin permissions
#     # TODO: Delete from OpenAI if uploaded
#     # TODO: Delete from S3 (optional)
#     # TODO: Delete from DB
#   end

#   # POST /api/admin/documents/:id/upload_to_openai
#   # Upload document to OpenAI Files API (admin only)
#   # Returns: OpenAI file ID
#   def upload_to_openai
#     # TODO: Validate admin permissions
#     # TODO: Download from S3
#     # TODO: Upload to OpenAI Files API
#     # TODO: Store OpenAI file ID
#     # TODO: Update document status
#     # TODO: Handle OpenAI API errors
#   end

#   # POST /api/admin/documents/:id/remove_from_openai
#   # Remove document from OpenAI (admin only)
#   # Returns: success message
#   def remove_from_openai
#     # TODO: Validate admin permissions
#     # TODO: Delete from OpenAI Files API
#     # TODO: Clear OpenAI file ID
#     # TODO: Update document status
#   end

#   # GET /api/admin/documents/sync_status
#   # Check sync status between DB and OpenAI (admin only)
#   # Returns: sync status report
#   def sync_status
#     # TODO: Validate admin permissions
#     # TODO: Compare DB records with OpenAI files
#     # TODO: Return mismatches
#     # TODO: Include file status details
#   end

  private

  def set_document
    # TODO: Find document by ID
    # TODO: Check if document exists
    # TODO: Handle not found errors
  end

  def require_admin
    # TODO: Check if current_user is admin
    # TODO: Return unauthorized error if not admin
  end

  def document_params
    # TODO: Define permitted parameters for document creation/update
    # TODO: Add validation rules
  end

  def generate_s3_url
    # TODO: Generate pre-signed S3 URL
    # TODO: Set appropriate headers
    # TODO: Handle S3 configuration errors
  end

  def validate_s3_file
    # TODO: Check if S3 file exists
    # TODO: Validate file size
    # TODO: Check file permissions
  end
end
