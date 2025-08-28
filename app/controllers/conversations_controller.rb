class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: [:show, :update, :destroy, :messages]

  # GET /api/conversations
  # List user's conversations with pagination (lazy loading)
  # Params: limit (default: 20), before_id (for infinite scroll)
  # Returns: conversations array, has_more flag, oldest_conversation_id
  def index
    # TODO: Implement pagination logic
    # TODO: Add before_id filtering for infinite scroll
    # TODO: Include message_count and last_message_at
    # TODO: Order by updated_at desc
  end

  # POST /api/conversations
  # Create new conversation and OpenAI thread
  # Params: title (optional)
  # Returns: conversation object with openai_thread_id
  def create
    # TODO: Create OpenAI thread via OpenAI API
    # TODO: Store conversation in DB with thread_id
    # TODO: Handle OpenAI API errors
    # TODO: Return conversation with thread_id
  end

  # GET /api/conversations/:id
  # Get single conversation details
  # Returns: conversation object with metadata
  def show
    # TODO: Return conversation with message_count, last_message_at
    # TODO: Include user permissions check
  end

  # PUT /api/conversations/:id
  # Update conversation (mainly title)
  # Params: title
  # Returns: updated conversation
  def update
    # TODO: Update conversation title
    # TODO: Update OpenAI thread metadata if needed
    # TODO: Handle validation errors
  end

  # DELETE /api/conversations/:id
  # Delete conversation and associated OpenAI thread
  # Returns: success message
  def destroy
    # TODO: Delete OpenAI thread via API
    # TODO: Delete conversation from DB (cascade will handle messages)
    # TODO: Handle OpenAI API errors
  end

  # GET /api/conversations/:id/messages
  # Get conversation messages with pagination
  # Params: limit (default: 50), before_id, after_id
  # Returns: messages array, has_more flag, oldest_message_id, newest_message_id
  def messages
    # TODO: Implement pagination for messages
    # TODO: Handle before_id (load older messages)
    # TODO: Handle after_id (load newer messages for real-time updates)
    # TODO: Parse JSON content for assistant messages
    # TODO: Include citation data
  end

  # POST /api/conversations/:id/messages
  # Send message to conversation (main chat endpoint)
  # Params: content, prepend_web_summary (optional)
  # Returns: assistant response with streaming flag
  def send_message
    # TODO: Store user message in DB
    # TODO: Add message to OpenAI thread
    # TODO: Create OpenAI run with assistant
    # TODO: Handle streaming response
    # TODO: Store assistant response in DB
    # TODO: Parse JSON response (answer, citations, needs_consent)
    # TODO: Update conversation updated_at timestamp
  end

#   # POST /api/conversations/:id/allow_web_search
#   # Handle web search consent and perform external search
#   # Params: allow (boolean), query
#   # Returns: web search results
#   def allow_web_search
#     # TODO: Validate consent
#     # TODO: Call external search API (Tavily/Perplexity)
#     # TODO: Store web search results
#     # TODO: Return formatted response
#   end

#   # GET /api/conversations/:id/stream
#   # Stream real-time response from OpenAI
#   # Returns: Server-Sent Events stream
#   def stream
#     # TODO: Implement SSE streaming
#     # TODO: Stream OpenAI response chunks
#     # TODO: Handle connection drops
#     # TODO: Update message in real-time
#   end

#   private

#   def set_conversation
#     # TODO: Find conversation by ID
#     # TODO: Check user ownership
#     # TODO: Handle not found errors
#   end

#   def conversation_params
#     # TODO: Define permitted parameters
#     # TODO: Add validation
#   end

#   def message_params
#     # TODO: Define permitted message parameters
#     # TODO: Add content validation
#   end
end
