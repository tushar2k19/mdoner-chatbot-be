class Api::ConversationsController < ApplicationController
  # This runs before any action - ensures user is logged in
  before_action :authenticate_user!
   require_dependency 'openai_service'
  # This finds the conversation and checks if user owns it (for show/destroy actions)
  before_action :find_conversation, only: [:show, :destroy, :update]

  # POST /api/conversations
  # Creates a new conversation with OpenAI thread 
  def create
    # Step 1: Create the conversation record in our database
    @conversation = current_user.conversations.build(conversation_params)
    
    # Step 2: Generate a title if user didn't provide one
    if @conversation.title.blank?
      @conversation.title = "New Conversation #{Time.current.strftime('%m/%d %H:%M')}"
    end
    
    begin
      # Step 3: Create OpenAI thread first (before saving to database)
      openai_service = OpenaiService.new
      thread_id = openai_service.create_thread
      
      # Step 4: Store the OpenAI thread ID in our conversation
      @conversation.openai_thread_id = thread_id
      
      # Step 5: Save the conversation to database
      if @conversation.save
        # Success response - return the conversation data
        render_success(
          { conversation: format_conversation_response(@conversation) },
          message: "Conversation created successfully",
          status: :created
        )
      else
        # Database validation failed
        render_error(
          'VALIDATION_ERROR',
          'Failed to create conversation',
          details: @conversation.errors.full_messages
        )
      end
      
    rescue => e
      # OpenAI API failed or other unexpected error
      Rails.logger.error "Failed to create conversation: #{e.message}"
      render_error(
        'CONVERSATION_CREATION_FAILED',
        'Unable to create conversation. Please try again.',
        details: e.message,
        status: :service_unavailable
      )
    end
  end

  # GET /api/conversations
  # Lists user's conversations with pagination (EFFICIENT VERSION)
  def index
    limit = params[:limit]&.to_i || 20
    before_id = params[:before_id]&.to_i

    # Step 1: Build the base query
    conversations_query = current_user.conversations
                                       .where(status: 'active')
                                       .order(updated_at: :desc)
                                       .limit(limit)

    # Step 2: Add pagination condition
    if before_id.present?
      conversations_query = conversations_query.where('id < ?', before_id)
    end

    # Step 3: Use SQL to calculate message stats in ONE query
    @conversations = conversations_query
                      .left_joins(:messages)
                      .group('conversations.id')
                      .select(
                        'conversations.*',
                        'COUNT(messages.id) AS message_count',
                        'MAX(messages.created_at) AS last_message_at'
                      )

    has_more = @conversations.length == limit
    oldest_conversation_id = @conversations.last&.id

    # Step 4: Format the response
    render_success({
      conversations: @conversations.map { |conv| format_conversation_response(conv) },
      pagination: {
        has_more: has_more,
        oldest_conversation_id: oldest_conversation_id
      }
    })
  end

  # GET /api/conversations/:id
  # Get single conversation details
  def show
    render_success({
    conversation: format_conversation(@conversation),
    message_count: @conversation.message_count,
    last_message_at: @conversation.last_message_at,
    created_at: @conversation.created_at.iso8601,
    updated_at: @conversation.updated_at.iso8601
  })
  end

  # PUT /api/conversations/:id
  # Updates conversation title
  def update
    begin
      if @conversation.update(conversation_params)
        render json: {
          conversation: format_conversation(@conversation),
          message: "Conversation updated successfully"
        }
      else
        render json: {
          error: {
            code: "VALIDATION_ERROR",
            message: "Failed to update conversation",
            details: @conversation.errors.full_messages
          }
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Failed to update conversation #{@conversation.id}: #{e.message}"
      render json: {
        error: {
          code: "UPDATE_FAILED",
          message: "Unable to update conversation. Please try again.",
          details: e.message
        }
      }, status: :service_unavailable
    end
  end

  # DELETE /api/conversations/:id
  # Soft deletes a conversation (marks as deleted, doesn't remove from DB)
  def destroy
    begin
      # Step 1: Mark conversation as deleted (soft delete)
      @conversation.update!(status: 'deleted')
      
      # Step 2: Mark all messages as deleted too
      @conversation.messages.update_all(updated_at: Time.current)
      
      # Step 3: Log the deletion for audit purposes
      Rails.logger.info "User #{current_user.id} deleted conversation #{@conversation.id}"
      
      # Step 4: Return success response
          render_success(
      { message: "Conversation deleted successfully" },
      message: "Conversation deleted successfully"
    )
      
    rescue => e
      # Handle any unexpected errors
      Rails.logger.error "Failed to delete conversation #{@conversation.id}: #{e.message}"
      render_error(
        'DELETION_FAILED',
        'Unable to delete conversation. Please try again.',
        details: e.message,
        status: :service_unavailable
)
    end
  end

  private

  # Finds conversation and verifies user ownership
  def find_conversation
    @conversation = current_user.conversations.find_by(id: params[:id], status: 'active')
    
    unless @conversation
      render_error(
        'CONVERSATION_NOT_FOUND',
        'Conversation not found or access denied',
        status: :not_found
      )
    end
  end

  # Permits only allowed parameters for conversation creation
  def conversation_params
    params.permit(:title)
  end

  # Formats conversation data for API response
  def format_conversation(conversation)
    {
      id: conversation.id,
      title: conversation.title,
      user_id: conversation.user_id,
      openai_thread_id: conversation.openai_thread_id,
      status: conversation.status,
      created_at: conversation.created_at.iso8601,
      updated_at: conversation.updated_at.iso8601
    }
  end
end