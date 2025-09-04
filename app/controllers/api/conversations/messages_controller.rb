class Api::Conversations::MessagesController < ApplicationController
  # Ensure user is logged in
  before_action :authenticate_user!
  
  # Find the conversation and check ownership
  before_action :find_conversation
  
  # GET /api/conversations/:conversation_id/messages
  # Get conversation messages with pagination
  def index
    limit = params[:limit]&.to_i || 50
    before_id = params[:before_id]&.to_i
    after_id = params[:after_id]&.to_i

    # Build the base query
    messages_query = @conversation.messages.order(created_at: :asc)
    
    # Add pagination conditions
    if before_id.present?
      messages_query = messages_query.where('id < ?', before_id)
    end
    
    if after_id.present?
      messages_query = messages_query.where('id > ?', after_id)
    end
    
    # Get messages with limit
    @messages = messages_query.limit(limit)
    
    # Check if there are more messages
    has_more = if before_id.present?
      @conversation.messages.where('id < ?', before_id).exists?
    else
      @conversation.messages.where('id > ?', @messages.last&.id).exists?
    end
    
    # Format response
    render json: {
      messages: @messages.map { |msg| format_message(msg) },
      has_more: has_more,
      oldest_message_id: @messages.first&.id,
      newest_message_id: @messages.last&.id
    }
  end

  # POST /api/conversations/:conversation_id/messages
  # Send a message and get AI response
  def create
    # Step 1: Save user message to database
    user_message = @conversation.messages.create!(
      role: 'user',
      content: message_params[:content],
      source: 'dpr'
    )
    
    # Step 2: Check if we need to prepend web summary
    prepend_web_summary = message_params[:prepend_web_summary]
    
    # Step 3: Send to OpenAI and get response
    begin
      openai_service = OpenaiService.new
      
      # Prepare the message content
      message_content = user_message.content
      if prepend_web_summary.present?
        message_content = "#{prepend_web_summary}\n\nUser question: #{user_message.content}"
      end
      
      # Process message through OpenAI
      ai_response = openai_service.process_message(
        @conversation.openai_thread_id, 
        message_content
      )
      
      # Step 4: Save AI response to database
      assistant_message = @conversation.messages.create!(
        role: 'assistant',
        content: ai_response.to_json,
        source: ai_response['needs_consent'] ? 'web' : 'dpr'
      )
      
      # Step 5: Return formatted response
      render_success({
      message: format_message(assistant_message),
      streaming: false
    })
      
    rescue => e
      # Handle OpenAI errors
      Rails.logger.error "OpenAI error: #{e.message}"
      
      # Create error response message
      error_message = @conversation.messages.create!(
        role: 'assistant',
        content: {
          answer: "I'm sorry, I encountered an error processing your request.",
          citations: [],
          needs_consent: false,
          message: "Please try again later."
        }.to_json,
        source: 'dpr'
      )
      
      render_error(
      'OPENAI_ERROR',
      'Unable to process message',
      details: e.message,
      status: :service_unavailable
    )
    end
  end

  private

  # Find conversation and verify user ownership
  def find_conversation
    @conversation = current_user.conversations.find_by(
      id: params[:conversation_id], 
      status: 'active'
    )
    
    unless @conversation
      render_error(
      'CONVERSATION_NOT_FOUND',
      'Conversation not found or access denied',
      status: :not_found
    )
    end
  end

  # Permit allowed parameters
  def message_params
    params.permit(:content, :prepend_web_summary)
  end

  # Format message for API response
  def format_message(message)
    {
      id: message.id,
      role: message.role,
      content: message.role == 'user' ? message.content : message.content_data,
      source: message.source,
      created_at: message.created_at.iso8601
    }
  end
end