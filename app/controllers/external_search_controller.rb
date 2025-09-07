class ExternalSearchController < ApplicationController
  # This controller handles external web search requests
  
  # Before any action, make sure user is authenticated
  before_action :authenticate_user!
  
  # POST /api/external_search/search
  # Perform external web search using Perplexity
  # Params: query, conversation_id
  # Returns: search results with citations
  def search
    begin
      # Get the search parameters
      query = params[:query]
      conversation_id = params[:conversation_id]
      
      # Validate required parameters
      if query.blank?
        return render json: {
          error: {
            code: "MISSING_PARAMETER",
            message: "Query parameter is required"
          }
        }, status: :bad_request
      end
      
      if conversation_id.blank?
        return render json: {
          error: {
            code: "MISSING_PARAMETER", 
            message: "Conversation ID is required"
          }
        }, status: :bad_request
      end
      
      # Find the conversation (using helper method)
      conversation = find_conversation(conversation_id)
      
      # Create Perplexity service instance
      perplexity_service = PerplexityService.new
      
      # Perform the search
      search_result = perplexity_service.search(query, conversation_id)
      
      # Create a new message with the search result
      message = Message.create_web_response(
        conversation, 
        search_result[:answer], 
        search_result[:citations]
      )
      
      # Return the search result (following your app's format)
      render json: {
        message: format_message(message),
        search_metadata: {
          query: query,
          provider: 'perplexity',
          timestamp: Time.current
        }
      }
      
    rescue => error
      Rails.logger.error "External search error: #{error.message}"
      render json: {
        error: {
          code: "SEARCH_FAILED",
          message: "Unable to perform web search",
          details: error.message
        }
      }, status: :service_unavailable
    end
  end
  
  # POST /api/external_search/consent
  # Handle user consent for web search
  # Params: conversation_id, query, allow
  # Returns: consent status
  def consent
    begin
      conversation_id = params[:conversation_id]
      query = params[:query]
      allow = params[:allow]
      
      # Validate parameters
      if conversation_id.blank? || query.blank? || allow.nil?
        return render json: {
          error: {
            code: "MISSING_PARAMETER",
            message: "Missing required parameters"
          }
        }, status: :bad_request
      end
      
      # Find the conversation (using helper method)
      conversation = find_conversation(conversation_id)
      
      if allow == true || allow == 'true'
        # User gave consent, perform the search
        search_result = search
        return search_result
      else
        # User denied consent, return a message
        message = Message.create!(
          conversation: conversation,
          role: 'assistant',
          content: "I understand you don't want to search the internet. Is there anything else I can help you with regarding the DPR documents?",
          source: 'dpr'
        )
        
        render json: {
          message: format_message(message)
        }
      end
      
    rescue => error
      Rails.logger.error "Consent handling error: #{error.message}"
      render json: {
        error: {
          code: "CONSENT_FAILED",
          message: "Unable to handle consent",
          details: error.message
        }
      }, status: :service_unavailable
    end
  end
  
  # GET /api/external_search/providers
  # List available search providers
  # Returns: provider list with status
  def providers
    render json: {
      providers: [
        {
          name: 'perplexity',
          display_name: 'Perplexity AI',
          status: 'active',
          description: 'AI-powered web search with real-time information'
        }
      ]
    }
  end
  
  private
  
  # Helper method to find conversation and check ownership
  # This eliminates code duplication
  def find_conversation(conversation_id)
    conversation = current_user.conversations.find_by(
      id: conversation_id, 
      status: 'active'
    )
    
    unless conversation
      raise "Conversation not found or access denied"
    end
    
    conversation
  end
  
  # Format message for API response (matching your app's format)
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