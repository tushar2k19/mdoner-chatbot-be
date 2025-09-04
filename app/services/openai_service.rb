class OpenaiService
  include HTTParty
  
  # Base configuration
  base_uri 'https://api.openai.com/v1'
  
  def initialize
    @api_key = ENV['OPENAI_API_KEY']
    @assistant_id = ENV['OPENAI_ASSISTANT_ID']
    @model = ENV['OPENAI_MODEL'] || 'gpt-4.1-nano'
    
    # Set default headers for all requests
    @headers = {
      'Authorization' => "Bearer #{@api_key}",
      'Content-Type' => 'application/json',
      'OpenAI-Beta' => 'assistants=v2'  # Use latest assistants API
    }
  end

  # Create a new OpenAI thread
  def create_thread
    retry_request(max_attempts: 3, delay: 2) do
      response = self.class.post('/threads', headers: @headers)
      
      if response.success?
        thread_data = JSON.parse(response.body)
        Rails.logger.info "Created OpenAI thread: #{thread_data['id']}"
        thread_data['id']
      else
        Rails.logger.error "Failed to create OpenAI thread: #{response.body}"
        raise "OpenAI API error: #{response.code} - #{response.body}"
      end
    end
  end

  # Send a message to an existing thread
  def send_message(thread_id, content, file_ids: [])
    retry_request(max_attempts: 3, delay: 1) do
      payload = {
        role: 'user',
        content: content
      }
      
      # Add file IDs if provided (for document search)
      payload[:file_ids] = file_ids if file_ids.any?
      
      response = self.class.post(
        "/threads/#{thread_id}/messages",
        headers: @headers,
        body: payload.to_json
      )
      
      if response.success?
        message_data = JSON.parse(response.body)
        Rails.logger.info "Sent message to thread #{thread_id}: #{message_data['id']}"
        message_data['id']
      else
        Rails.logger.error "Failed to send message: #{response.body}"
        raise "OpenAI API error: #{response.code} - #{response.body}"
      end
    end
  end

  # Create a run to process the message
  def create_run(thread_id, instructions: nil)
    retry_request(max_attempts: 3, delay: 1) do
      payload = {
        assistant_id: @assistant_id
      }
      
      # Add custom instructions if provided
      payload[:instructions] = instructions if instructions.present?
      
      response = self.class.post(
        "/threads/#{thread_id}/runs",
        headers: @headers,
        body: payload.to_json
      )
      
      if response.success?
        run_data = JSON.parse(response.body)
        Rails.logger.info "Created run for thread #{thread_id}: #{run_data['id']}"
        run_data['id']
      else
        Rails.logger.error "Failed to create run: #{response.body}"
        raise "OpenAI API error: #{response.code} - #{response.body}"
      end
    end
  end

  # Get the status of a run
  def get_run_status(thread_id, run_id)
    response = self.class.get(
      "/threads/#{thread_id}/runs/#{run_id}",
      headers: @headers
    )
    
    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to get run status: #{response.body}"
      raise "OpenAI API error: #{response.code} - #{response.body}"
    end
  end

  # Get messages from a thread
  def get_thread_messages(thread_id, limit: 20)
    response = self.class.get(
      "/threads/#{thread_id}/messages?limit=#{limit}",
      headers: @headers
    )
    
    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.error "Failed to get thread messages: #{response.body}"
      raise "OpenAI API error: #{response.code} - #{response.body}"
    end
  end

  # Wait for a run to complete (with timeout)
  def wait_for_run_completion(thread_id, run_id, timeout: 60)
    start_time = Time.current
    
    loop do
      run_data = get_run_status(thread_id, run_id)
      status = run_data['status']
      
      case status
      when 'completed'
        Rails.logger.info "Run #{run_id} completed successfully"
        return run_data
      when 'failed', 'cancelled', 'expired'
        error_msg = run_data['last_error']&.dig('message') || "Run #{status}"
        Rails.logger.error "Run #{run_id} #{status}: #{error_msg}"
        raise "OpenAI run #{status}: #{error_msg}"
      when 'requires_action'
        Rails.logger.info "Run #{run_id} requires action"
        return run_data
      else
        # Still running, check timeout
        if Time.current - start_time > timeout
          raise "OpenAI run timeout after #{timeout} seconds"
        end
        
        # Wait before checking again
        sleep(1)
      end
    end
  end

  # Process a complete conversation flow
  def process_message(thread_id, user_message, file_ids: [])
    begin
      # Step 1: Send user message
      message_id = send_message(thread_id, user_message, file_ids: file_ids)
      
      # Step 2: Create run
      run_id = create_run(thread_id)
      
      # Step 3: Wait for completion
      run_data = wait_for_run_completion(thread_id, run_id)
      
      # Step 4: Get the response
      messages = get_thread_messages(thread_id, limit: 1)
      assistant_message = messages['data'].first
      
      # Step 5: Parse the response
      parse_assistant_response(assistant_message)
      
    rescue => e
      Rails.logger.error "Error processing message: #{e.message}"
      raise e
    end
  end

  # Process message with streaming updates
  def process_message_with_streaming(thread_id, user_message, streaming)
    # Send status update to frontend
    streaming.send_status_update("Sending message to AI...")

    # Step 1: Send user message to OpenAI
    send_message(thread_id, user_message)
    
    # Send status update
    streaming.send_status_update("AI is thinking...")

    # Step 2: Create run to process the message
    run_id = create_run(thread_id)
    
    # Step 3: Wait for completion with streaming updates
    wait_for_run_completion_with_streaming(thread_id, run_id, streaming)
    
    # Step 4: Get the final response
    messages = get_thread_messages(thread_id, limit: 1)
    assistant_message = messages['data'].first
    
    # Step 5: Parse the response and return
    parse_assistant_response(assistant_message)
  end

  private

  # Wait for run completion with streaming updates
  def wait_for_run_completion_with_streaming(thread_id, run_id, streaming)
    attempt = 0
    max_attempts = 30
    
    loop do
      attempt += 1
      
      # Check if we've exceeded max attempts
      if attempt > max_attempts
        streaming.send_error("AI is taking too long to respond. Please try again.")
        return { 
          'answer' => "Error: Timeout", 
          'citations' => [], 
          'needs_consent' => false,
          'message' => "Please try again later."
        }
      end

      # Get the current status
      run_data = get_run_status(thread_id, run_id)
      status = run_data['status']
      
      case status
      when 'completed'
        # AI is done, get the response
        streaming.send_status_update("Processing final response...")
        return run_data
        
      when 'failed', 'cancelled', 'expired'
        # Something went wrong
        error_msg = run_data['last_error']&.dig('message') || "Run #{status}"
        streaming.send_error("AI failed to process your request: #{error_msg}")
        return { 
          'answer' => "Error: AI processing failed", 
          'citations' => [], 
          'needs_consent' => false,
          'message' => "Please try again later."
        }
        
      when 'requires_action'
        # AI needs more information (like web search consent)
        streaming.send_status_update("AI needs more information...")
        # For now, just wait and retry
        sleep(2)
        
      else
        # Still processing - send status update
        streaming.send_status_update("AI is working on your request...")
        sleep(2)
      end
    end
  end

  # Parse the assistant response to extract answer, citations, etc.
  def parse_assistant_response(assistant_message)
    content = assistant_message['content'].first
    
    if content['type'] == 'text'
      text_content = content['text']['value']
      
      # Extract citations from annotations AND text content
      citations = extract_citations_from_message(assistant_message)
      
      # Try to parse as JSON (for structured responses)
      begin
        parsed = JSON.parse(text_content)
        
        # ALWAYS override citations with what we extracted
        parsed['citations'] = citations
        
        return parsed
      rescue JSON::ParserError
        # Fallback to plain text with extracted citations
        return {
          'answer' => text_content,
          'citations' => citations,
          'needs_consent' => false
        }
      end
    else
      # Handle other content types if needed
      return {
        'answer' => 'Unsupported content type',
        'citations' => [],
        'needs_consent' => false
      }
    end
  end

  # Extract citations from message
  def extract_citations_from_message(assistant_message)
    citations = []
    
    # Method 1: Look for file_search annotations (primary method)
    if assistant_message['content'].present?
      assistant_message['content'].each do |content_item|
        if content_item['type'] == 'text' && content_item['text']['annotations'].present?
          content_item['text']['annotations'].each do |annotation|
            if annotation['type'] == 'file_search'
              file_id = annotation['file_search']['file_id']
            # Use your existing DocumentMapper
            document_name = DocumentMapper.file_id_to_document_name(file_id)
            citations << document_name if document_name.present?
            end
          end
        end
      end
    end
    
    # Method 2: Look for citations in the text content (fallback)
    if assistant_message['content'].present?
      assistant_message['content'].each do |content_item|
        if content_item['type'] == 'text'
          text_content = content_item['text']['value']
          
          # Look for citation patterns like 【20:0†Nagaland_Innovation_Hub.pdf】
          text_content.scan(/【.*?†(.*?\.pdf)】/) do |match|
            citations << match[0] if match[0].present?
          end
          
          # Look for other citation patterns
          text_content.scan(/\[(.*?\.pdf)\]/) do |match|
            citations << match[0] if match[0].present?
          end
        end
      end
    end
    
    # Remove duplicates and return
    citations.uniq
  end

  # Retry mechanism for failed requests
  def retry_request(max_attempts: 3, delay: 1)
    attempts = 0
    
    begin
      attempts += 1
      yield  # This will execute the code you pass to the method
    rescue => e
      if attempts < max_attempts
        Rails.logger.warn "Request failed (attempt #{attempts}/#{max_attempts}): #{e.message}. Retrying in #{delay} seconds..."
        sleep(delay)
        retry  # Try again
      else
        Rails.logger.error "Request failed after #{max_attempts} attempts: #{e.message}"
        raise e  # Give up and raise the error
      end
    end
  end
end