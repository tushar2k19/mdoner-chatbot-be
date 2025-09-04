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
    render_success({
    messages: @messages.map { |msg| format_message_response(msg) },
    pagination: {
      has_more: has_more,
      oldest_message_id: @messages.first&.id,
      newest_message_id: @messages.last&.id
    }
  })
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
    
    # Step 2: Check if the request wants streaming
    if request.headers['Accept']&.include?('text/event-stream')
      # User wants streaming response
      handle_streaming_response(user_message)
    else
      # User wants regular response (for testing)
      handle_regular_response(user_message)
    end
  end
  
  private
  
  def handle_streaming_response(user_message)
    # Set up streaming response headers
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Connection'] = 'keep-alive'
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Cache-Control'
  
    # Create streaming service
    streaming = StreamingService.new(response)
  
    begin
      # Send initial status
      streaming.send_status_update("Processing your message...")
  
      # Check if we need to prepend web summary
      prepend_web_summary = message_params[:prepend_web_summary]
      
      # Prepare the message content
      message_content = user_message.content
      if prepend_web_summary.present?
        message_content = "#{prepend_web_summary}\n\nUser question: #{user_message.content}"
      end
  
      # Send to OpenAI and get streaming response
      openai_service = OpenaiService.new
      ai_response = openai_service.process_message_with_streaming(
        @conversation.openai_thread_id,
        message_content,
        streaming
      )
  
      # Save the complete AI response
      @conversation.messages.create!(
        role: 'assistant',
        content: ai_response.to_json,
        source: ai_response['needs_consent'] ? 'web' : 'dpr'
      )
  
      # Send completion event
      streaming.send_complete_response(
        ai_response['answer'],
        ai_response['citations']
      )
  
    rescue => e
      # Handle any errors
      streaming.send_error("Sorry, something went wrong. Please try again.")
      Rails.logger.error "Streaming error: #{e.message}"
    ensure
      # Always close the stream
      response.stream.close
    end
  end
  
  def handle_regular_response(user_message)
    # This is your existing logic for non-streaming requests
    # Keep this for testing and fallback
    
    begin
      # Check if we need to prepend web summary
      prepend_web_summary = message_params[:prepend_web_summary]
      
      # Prepare the message content
      message_content = user_message.content
      if prepend_web_summary.present?
        message_content = "#{prepend_web_summary}\n\nUser question: #{user_message.content}"
      end
  
      # Create OpenAI service instance
      openai_service = OpenaiService.new
      
      # Process message through OpenAI
      ai_response = openai_service.process_message(
        @conversation.openai_thread_id, 
        message_content
      )
      
      # Save AI response to database
      assistant_message = @conversation.messages.create!(
        role: 'assistant',
        content: ai_response.to_json,
        source: ai_response['needs_consent'] ? 'web' : 'dpr'
      )
      
      # Return formatted response
      render_success({
        message: format_message_response(assistant_message),
        streaming: false
      })
      
    rescue => e
      # Handle OpenAI errors
      Rails.logger.error "OpenAI error: #{e.message}"
      
      # Create error response message
      @conversation.messages.create!(
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

end