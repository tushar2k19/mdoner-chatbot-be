module ApiResponseFormatter
  extend ActiveSupport::Concern

  # Standard success response format
  def render_success(data, message: nil, status: :ok)
    response = {
      success: true,
      data: data
    }
    
    response[:message] = message if message.present?
    
    render json: response, status: status
  end

  # Standard error response format
  def render_error(code, message, details: nil, status: :unprocessable_entity)
    error_response = {
      success: false,
      error: {
        code: code,
        message: message,
        timestamp: Time.current.iso8601
      }
    }
    
    error_response[:error][:details] = details if details.present?
    
    render json: error_response, status: status
  end

  # Standard pagination response format
  def render_paginated(data, pagination_info)
    render json: {
      success: true,
      data: data,
      pagination: pagination_info
    }
  end

  # Standard conversation response format
  def format_conversation_response(conversation)
    {
      id: conversation.id,
      title: conversation.title,
      message_count: conversation.message_count,
      created_at: conversation.created_at.iso8601,
      updated_at: conversation.updated_at.iso8601,
      last_message_at: conversation.last_message_at&.iso8601
    }
  end

  # Standard message response format
  def format_message_response(message)
    {
      id: message.id,
      role: message.role,
      content: message.role == 'user' ? message.content : message.content_data,
      source: message.source,
      created_at: message.created_at.iso8601
    }
  end

  # Standard user response format
  def format_user_response(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      created_at: user.created_at.iso8601
    }
  end
end