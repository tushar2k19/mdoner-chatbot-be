class OpenaiService
  include HTTParty
  
  # Base configuration
  base_uri 'https://api.openai.com/v1'
  
  def initialize
    @api_key = ENV['OPENAI_API_KEY']
    @assistant_id = ENV['OPENAI_ASSISTANT_ID']
    @model = ENV['OPENAI_MODEL'] || 'gpt-4.1-nano'
    
     # Log the actual values (be careful with sensitive data)
     Rails.logger.info "API Key length: #{@api_key&.length || 0}"
     Rails.logger.info "Assistant ID: #{@assistant_id}"
     Rails.logger.info "Model: #{@model}"
     Rails.logger.info "================================"


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

  private

  # Parse the assistant response to extract answer, citations, etc.
 # Update the parse_assistant_response method
def parse_assistant_response(assistant_message)
  content = assistant_message['content'].first
  
  if content['type'] == 'text'
    text_content = content['text']['value']
    
    # Extract citations from annotations AND text content
    citations = extract_citations_from_message(assistant_message)

    # Check if the response indicates no information found
    needs_consent = check_if_needs_consent(text_content, citations)
    
    # Try to parse as JSON (for structured responses)
    begin
      parsed = JSON.parse(text_content)
      
      # ALWAYS override citations with what we extracted
      parsed['citations'] = citations
      # ALWAYS override needs_consent with our detection
      parsed['needs_consent'] = needs_consent
      
      return parsed
    rescue JSON::ParserError
      # Fallback to plain text with extracted citations
      return {
        'answer' => text_content,
        'citations' => citations,
        'needs_consent' => needs_consent
      }
    end
  else
    # Handle other content types if needed
    return {
      'answer' => 'Unsupported content type',
      'citations' => citations,
      'needs_consent' => false
    }
  end
end

def check_if_needs_consent(text_content, citations)
  # If there are citations, we found information in DPR documents
  return false if citations.any?
  
  text_lower = text_content.downcase
  
  # Analyze the response structure and content
  analysis = analyze_response_quality(text_content, text_lower)
  
  # Decision logic based on analysis
  case analysis[:confidence]
  when :high
    false  # High confidence answer, no consent needed
  when :medium
    # Medium confidence - check for specific indicators
    analysis[:has_negative_indicators] ? true : false
  when :low
    true   # Low confidence, needs consent
  end
end

private

def analyze_response_quality(text_content, text_lower)
  confidence = :medium
  has_negative_indicators = false
  has_positive_indicators = false
  
  # Check response length (very short responses are often incomplete)
  if text_content.length < 100
    confidence = :low
  elsif text_content.length > 300
    confidence = :high
  end
  
  # Check for negative indicators (strong signals of "not found")
  strong_negative_indicators = [
    'do not provide any information',
    'do not provide any details', 
    'do not provide any data',
    'not available in the provided documents',
    'not found in the documents',
    'not contain any specific information',
    'no information about',
    'cannot find information',
    'unable to find information',
    'therefore, there is no available information',
    'there is no available information'
  ]
  
  if strong_negative_indicators.any? { |indicator| text_lower.include?(indicator) }
    has_negative_indicators = true
    confidence = :low
  end
  
  # Check for positive indicators (strong signals of good answer)
  strong_positive_indicators = [
    'according to the documents',
    'based on the dpr',
    'the project includes',
    'the budget allocation',
    'the timeline shows',
    'the implementation plan',
    'the technical specifications',
    'the environmental impact',
    'the cost breakdown',
    'the project details',
    'the infrastructure includes',
    'the development plan',
    'the construction details',
    'the project aims to',
    'the initiative focuses on',
    'the development includes',
    'the construction involves',
    'the implementation involves',
    'the project involves',
    'the development involves'
  ]
  
  if strong_positive_indicators.any? { |indicator| text_lower.include?(indicator) }
    has_positive_indicators = true
    confidence = :high
  end
  
  # Check for deflection patterns (when AI gives related but not direct info)
  deflection_patterns = [
    'the available details primarily focus on',
    'while the documents contain information about',
    'although the documents include details about',
    'the documents provide information about',
    'primarily focus on',
    'the available information relates to',
    'the documents focus on',
    'the information available focuses on'
  ]
  
  if deflection_patterns.any? { |pattern| text_lower.include?(pattern) }
    has_negative_indicators = true
    confidence = :low
  end
  
  # Check for question-specific content
  # If the response doesn't contain the key terms from the question, it might be off-topic
  question_keywords = extract_question_keywords(text_content)
  if question_keywords.any? && !question_keywords.any? { |keyword| text_lower.include?(keyword.downcase) }
    confidence = :low
  end
  
  # Check for generic responses
  generic_responses = [
    'the documents provided do not contain',
    'no information available',
    'not available in the documents',
    'the documents do not provide',
    'the available information does not include'
  ]
  
  if generic_responses.any? { |pattern| text_lower.include?(pattern) }
    has_negative_indicators = true
    confidence = :low
  end
  
  {
    confidence: confidence,
    has_negative_indicators: has_negative_indicators,
    has_positive_indicators: has_positive_indicators
  }
end

def extract_question_keywords(text_content)
  # Extract key terms that should be in a good answer
  # This is a simple approach - you could make it more sophisticated
  keywords = []
  
  # Look for common question patterns
  if text_content.include?('CM') || text_content.include?('Chief Minister')
    keywords << 'chief minister'
  end
  
  if text_content.include?('thought') || text_content.include?('opinion')
    keywords << 'thought'
    keywords << 'opinion'
  end
  
  if text_content.include?('budget')
    keywords << 'budget'
  end
  
  if text_content.include?('timeline')
    keywords << 'timeline'
  end
  
  keywords
end

# Add this NEW method for citation extraction
# Update the extract_citations_from_message method
def extract_citations_from_message(assistant_message)
  citations = []
  
  # Method 1: Look for file_search annotations (primary method)
  if assistant_message['content'].present?
    assistant_message['content'].each do |content_item|
      if content_item['type'] == 'text' && content_item['text']['annotations'].present?
        content_item['text']['annotations'].each do |annotation|
          if annotation['type'] == 'file_search'
            file_id = annotation['file_search']['file_id']
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