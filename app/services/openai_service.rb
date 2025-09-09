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
      
      # Add attachments if file IDs are provided (for document search)
      if file_ids.any?
        payload[:attachments] = file_ids.map do |file_id|
          {
            file_id: file_id,
            tools: [{ type: "file_search" }]
          }
        end
      end
      
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
      messages_data = JSON.parse(response.body)
      
      # Log the response in a readable format
      Rails.logger.info "=== OpenAI Messages Response ==="
      Rails.logger.info "Thread ID: #{thread_id}"
      Rails.logger.info "Messages Count: #{messages_data['data']&.length || 0}"
      
      if messages_data['data']&.any?
        messages_data['data'].each_with_index do |message, index|
          Rails.logger.info "--- Message #{index + 1} ---"
          Rails.logger.info "Role: #{message['role']}"
          Rails.logger.info "Message ID: #{message['id']}"
          Rails.logger.info "Created At: #{message['created_at']}"
          
          if message['content']&.any?
            message['content'].each_with_index do |content, content_index|
              Rails.logger.info "Content #{content_index + 1} Type: #{content['type']}"
              
              if content['type'] == 'text'
                text_value = content['text']['value']
                Rails.logger.info "Text Content Length: #{text_value.length} characters"
                Rails.logger.info "Text Content Preview: #{text_value[0..200]}#{'...' if text_value.length > 200}"
                
                # Log annotations if present
                if content['text']['annotations']&.any?
                  Rails.logger.info "Annotations Count: #{content['text']['annotations'].length}"
                  content['text']['annotations'].each_with_index do |annotation, ann_index|
                    Rails.logger.info "  Annotation #{ann_index + 1}: #{annotation['type']}"
                    if annotation['type'] == 'file_search'
                      Rails.logger.info "    File ID: #{annotation['file_search']['file_id']}"
                    end
                  end
                end
              end
            end
          end
        end
      end
      
      Rails.logger.info "=== End OpenAI Messages Response ==="
      
      messages_data
    else
      Rails.logger.error "Failed to get thread messages: #{response.body}"
      raise "OpenAI API error: #{response.code} - #{response.body}"
    end
  end

  # Wait for a run to complete (with timeout)
  def wait_for_run_completion(thread_id, run_id, timeout: 60)
    start_time = Time.current
    Rails.logger.info "=== Waiting for Run Completion ==="
    Rails.logger.info "Thread ID: #{thread_id}"
    Rails.logger.info "Run ID: #{run_id}"
    Rails.logger.info "Timeout: #{timeout} seconds"
    
    loop do
      run_data = get_run_status(thread_id, run_id)
      status = run_data['status']
      elapsed_time = Time.current - start_time
      
      Rails.logger.info "Run status check - Status: #{status}, Elapsed: #{elapsed_time.round(2)}s"
      
      case status
      when 'completed'
        Rails.logger.info "Run #{run_id} completed successfully in #{elapsed_time.round(2)}s"
        Rails.logger.info "Run completion data: #{format_response_for_logging(run_data)}"
        Rails.logger.info "=== Run Completion Finished ==="
        return run_data
      when 'failed', 'cancelled', 'expired'
        error_msg = run_data['last_error']&.dig('message') || "Run #{status}"
        Rails.logger.error "Run #{run_id} #{status} after #{elapsed_time.round(2)}s: #{error_msg}"
        Rails.logger.error "Run error data: #{format_response_for_logging(run_data)}"
        raise "OpenAI run #{status}: #{error_msg}"
      when 'requires_action'
        Rails.logger.info "Run #{run_id} requires action after #{elapsed_time.round(2)}s"
        Rails.logger.info "Run action data: #{format_response_for_logging(run_data)}"
        Rails.logger.info "=== Run Completion Finished (Action Required) ==="
        return run_data
      else
        # Still running, check timeout
        if Time.current - start_time > timeout
          Rails.logger.error "Run #{run_id} timed out after #{timeout} seconds"
          raise "OpenAI run timeout after #{timeout} seconds"
        end
        
        # Log progress every 10 seconds
        if elapsed_time.round % 10 == 0 && elapsed_time > 0
          Rails.logger.info "Run #{run_id} still running... (#{elapsed_time.round(2)}s elapsed)"
        end
        
        # Wait before checking again
        sleep(1)
      end
    end
  end

  # Process a complete conversation flow
  def process_message(thread_id, user_message, file_ids: [])
    Rails.logger.info "=== Starting OpenAI Message Processing ==="
    Rails.logger.info "Thread ID: #{thread_id}"
    Rails.logger.info "User Message: #{user_message}"
    Rails.logger.info "File IDs: #{file_ids}"
    
    begin
      # Step 1: Send user message
      Rails.logger.info "Step 1: Sending user message..."
      message_id = send_message(thread_id, user_message, file_ids: file_ids)
      Rails.logger.info "Message sent with ID: #{message_id}"

      # Step 2: Create run
      Rails.logger.info "Step 2: Creating run..."
      run_id = create_run(thread_id)
      Rails.logger.info "Run created with ID: #{run_id}"

      # Step 3: Wait for completion
      Rails.logger.info "Step 3: Waiting for run completion..."
      run_data = wait_for_run_completion(thread_id, run_id)
      Rails.logger.info "Run completed with status: #{run_data['status']}"

      # Step 4: Get the response
      Rails.logger.info "Step 4: Getting thread messages..."
      messages = get_thread_messages(thread_id, limit: 1)
      assistant_message = messages['data'].first
      Rails.logger.info "Retrieved assistant message with ID: #{assistant_message['id']}"

      # Step 5: Parse the response
      Rails.logger.info "Step 5: Parsing assistant response..."
      final_response = parse_assistant_response(assistant_message)
      
      Rails.logger.info "=== OpenAI Message Processing Complete ==="
      Rails.logger.info "Final response structure: #{final_response.keys}"
      Rails.logger.info "Answer length: #{final_response['answer']&.length || 0} characters"
      Rails.logger.info "Citations count: #{final_response['citations']&.length || 0}"
      Rails.logger.info "Needs consent: #{final_response['needs_consent']}"
      
      final_response
      
    rescue => e
      Rails.logger.error "=== Error in OpenAI Message Processing ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      raise e
    end
  end

  private

  
  def parse_assistant_response(assistant_message)
    Rails.logger.info "=== Parsing Assistant Response ==="

    content = assistant_message['content'].first

    if content['type'] == 'text'
      text_content = content['text']['value']
      Rails.logger.info "Raw text content length: #{text_content.length} characters"
      Rails.logger.info "Raw text content: #{text_content}"

      # Try to parse as JSON (for structured responses) FIRST
      begin
        parsed = JSON.parse(text_content)
        Rails.logger.info "Successfully parsed as JSON"

        # Extract citations from the parsed JSON directly (assistant already handles this)
        citations = parsed['citations'] || []

        # Clean up citation format - remove page numbers if present (e.g., "8:2†Nagaland_Innovation_Hub.pdf" -> "Nagaland_Innovation_Hub.pdf")
        cleaned_citations = citations.map do |citation|
          if citation.include?('†')
            citation.split('†').last
          else
            citation
          end
        end.uniq

        # Convert file IDs to document names if they are file IDs
        converted_citations = cleaned_citations.map do |citation|
          # Check if this looks like a file ID (starts with 'file-')
          if citation.start_with?('file-')
            DocumentMapper.file_id_to_document_name(citation)
          else
            citation
          end
        end.compact.uniq

        parsed['citations'] = converted_citations
        Rails.logger.info "Extracted citations from JSON: #{cleaned_citations}"
        Rails.logger.info "Converted citations to document names: #{converted_citations}"

        # Use assistant's needs_consent directly if provided, otherwise detect
        if parsed.key?('needs_consent')
          Rails.logger.info "Using assistant's explicit needs_consent: #{parsed['needs_consent']}"
        else
          # Fallback: detect from content if assistant didn't specify
          detected_needs_consent = check_if_needs_consent(text_content, cleaned_citations)
          parsed['needs_consent'] = detected_needs_consent
          Rails.logger.info "Using detected needs_consent: #{detected_needs_consent}"
        end

        Rails.logger.info "Final parsed response: #{format_response_for_logging(parsed)}"
        Rails.logger.info "=== End Parsing Assistant Response ==="

        return parsed

      rescue JSON::ParserError => e
        Rails.logger.info "Failed to parse as JSON: #{e.message}"
        # Fallback: extract citations from annotations and text patterns
        citations = extract_citations_from_message(assistant_message)
        needs_consent = check_if_needs_consent(text_content, citations)

        final_response = {
          'answer' => text_content,
          'citations' => citations,
          'needs_consent' => needs_consent
        }

        Rails.logger.info "Final parsed response (fallback): #{format_response_for_logging(final_response)}"
        Rails.logger.info "=== End Parsing Assistant Response ==="

        return final_response
      end
    else
      Rails.logger.info "Unsupported content type: #{content['type']}"
      # Handle other content types if needed
      final_response = {
        'answer' => 'Unsupported content type',
        'citations' => [],
        'needs_consent' => false
      }

      Rails.logger.info "Final parsed response (unsupported): #{format_response_for_logging(final_response)}"
      Rails.logger.info "=== End Parsing Assistant Response ==="

      return final_response
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
  # Helper method to format response data for logging
  def format_response_for_logging(data, max_length: 500)
    return "nil" if data.nil?
    
    if data.is_a?(String)
      return data.length > max_length ? "#{data[0...max_length]}... (#{data.length} chars total)" : data
    elsif data.is_a?(Hash) || data.is_a?(Array)
      formatted = JSON.pretty_generate(data)
      return formatted.length > max_length ? "#{formatted[0...max_length]}... (#{formatted.length} chars total)" : formatted
    else
      return data.to_s
    end
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

    # ========================================
    # CHECKLIST ANALYSIS METHODS
    # ========================================

    # Ensure subsequent methods are public (a prior `private` call applies to later defs)
    public

    # Main method to analyze checklist items against documents
  def analyze_checklist(document_names:, checklist_items:)
    Rails.logger.info "=== Starting Checklist Analysis ==="
    Rails.logger.info "Documents to analyze: #{document_names}"
    Rails.logger.info "Checklist items count: #{checklist_items.length}"
    
    begin
      # Step 1: Create a temporary thread for this analysis
      thread_id = create_thread
      Rails.logger.info "Created analysis thread: #{thread_id}"
      
      # Step 2: Build the comprehensive prompt
      prompt = build_checklist_prompt(document_names, checklist_items)
      Rails.logger.info "Built checklist prompt (#{prompt.length} characters)"
      
      # Step 3: Map selected document names to OpenAI file IDs and send message with attachments
      selected_file_ids = Array(document_names).compact.map do |name|
        begin
          DocumentMapper.document_name_to_file_id(name)
        rescue => e
          Rails.logger.warn "DocumentMapper lookup failed for '#{name}': #{e.message}"
          nil
        end
      end.compact.uniq

      Rails.logger.info "Resolved #{selected_file_ids.length} file_ids for attachments"

      message_id = send_message(thread_id, prompt, file_ids: selected_file_ids)
      Rails.logger.info "Sent checklist message: #{message_id}"
      
      # Step 4: Create run with function definition
      run_id = create_checklist_run(thread_id)
      Rails.logger.info "Created checklist run: #{run_id}"
      
      # Step 5: Wait for completion (extended timeout for complex analysis)
      run_data = wait_for_run_completion(thread_id, run_id, timeout: 120)
      Rails.logger.info "Run completed with status: #{run_data['status']}"
      
      # Step 6: Process the response
      checklist_results = process_checklist_response(thread_id, run_data, checklist_items)
      
      Rails.logger.info "=== Checklist Analysis Completed Successfully ==="
      Rails.logger.info "Results count: #{checklist_results.length}"
      
      checklist_results
      
    rescue => e
      Rails.logger.error "=== Checklist Analysis Failed ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(3).join("\n")}"
      raise e
    end
  end
  
  # Build the comprehensive prompt for checklist analysis
  def build_checklist_prompt(document_names, checklist_items)
    document_list = document_names.map { |name| "- #{name}" }.join("\n")
    items_list = checklist_items.map.with_index(1) { |item, i| "#{i}. #{item}" }.join("\n")
    
    prompt = <<~PROMPT
      You are a DPR analysis assistant. Your task is to analyze the specified documents for the given checklist items.
      
      DOCUMENTS TO ANALYZE:
      #{document_list}
      
      IMPORTANT: The files are attached to this message. Use the file_search tool to access and read the content of these documents.
      
      CHECKLIST ITEMS TO VERIFY (ANALYZE EACH ONE INDIVIDUALLY):
      #{items_list}
      
      CRITICAL ANALYSIS REQUIREMENTS:
      You must analyze EACH checklist item separately and provide individual results. Do NOT provide a single summary.
      
      For EACH checklist item, determine:
      - Status: "Yes" if the item is fully covered in the DPR, "No" if not covered at all, "Partial" if partially covered
      - Remarks: DETAILED explanations as follows:
        * If "No": "Not covered in the [STATE_NAME] DPR" (replace [STATE_NAME] with actual state like Nagaland, Mizoram, etc.)
        * If "Partial": Brief explanation (40+ words) of what IS covered and what is NOT covered, and why you consider it partial
        * If "Yes": Comprehensive detailed response (100+ words) covering ALL aspects mentioned in the DPR including timelines, costs, specifications, requirements, etc.
      
      MANDATORY FUNCTION CALLING:
      - You MUST use the return_checklist_results function to provide your response
      - You MUST call this function with an array of results - ONE result for EACH checklist item
      - Do NOT return a regular JSON response or text response
      - Do NOT provide a single summary - analyze each item individually
      
      EXAMPLE OF EXPECTED OUTPUT:
      Call return_checklist_results with an array like:
      [
        {
          "item": "Project timeline and milestones",
          "status": "Yes",
          "remarks": "The Nagaland Innovation Hub DPR provides comprehensive timeline details..."
          
        },
        {
          "item": "Budget allocation and cost breakdown", 
          "status": "Partial",
          "remarks": "The document mentions total project cost but lacks detailed breakdown..."          "
        }
      ]
      
      Begin your analysis now. Search through the attached documents and call the return_checklist_results function with your findings for EACH checklist item.
    PROMPT
    
    prompt
  end
  
  # Create a run with function calling capability for checklist analysis
  def create_checklist_run(thread_id)
    retry_request(max_attempts: 3, delay: 1) do
      payload = {
        assistant_id: @assistant_id,
        instructions: "You MUST use the return_checklist_results function to provide your response. Analyze each checklist item individually and call the function with an array of results - one for each checklist item. Do not return regular JSON or text responses.",
        tools: [
          { type: "file_search" },
          {
            type: "function",
            function: {
              name: "return_checklist_results",
              description: "MANDATORY function to return structured checklist analysis results. You MUST call this function with an array of results - one entry for each checklist item. Do NOT provide a single summary.",
              parameters: {
                type: "object",
                properties: {
                  results: {
                    type: "array",
                    description: "Array of checklist analysis results - MUST have one entry for each checklist item. Do NOT provide a single summary entry.",
                    items: {
                      type: "object",
                      properties: {
                        item: { 
                          type: "string", 
                          description: "The exact checklist item name being analyzed" 
                        },
                        status: { 
                          type: "string", 
                          enum: ["Yes", "No", "Partial"],
                          description: "Yes if the item is fully covered in the DPR, No if not covered at all, Partial if partially covered" 
                        },
                        remarks: { 
                          type: "string", 
                          description: "DETAILED explanations: If 'No': 'Not covered in the [STATE_NAME] DPR'. If 'Partial': 40+ words explaining what IS and ISN'T covered and why it's partial. If 'Yes': 100+ words covering ALL aspects from DPR including timelines, costs, specifications, requirements, etc." 
                        },
                      },
                      required: ["item", "status", "remarks"]
                    }
                  }
                },
                required: ["results"]
              }
            }
          }
        ]
      }
      
      response = self.class.post(
        "/threads/#{thread_id}/runs",
        headers: @headers,
        body: payload.to_json
      )
      
      if response.success?
        run_data = JSON.parse(response.body)
        Rails.logger.info "Created checklist run: #{run_data['id']}"
        run_data['id']
      else
        Rails.logger.error "Failed to create checklist run: #{response.body}"
        raise "OpenAI API error: #{response.code} - #{response.body}"
      end
    end
  end
  
  # Process the response from checklist analysis
  def process_checklist_response(thread_id, run_data, original_checklist_items = [])
    Rails.logger.info "=== Processing Checklist Response ==="
    Rails.logger.info "Run status: #{run_data['status']}"
    
    case run_data['status']
    when 'completed'
      # Get the assistant's response
      messages = get_thread_messages(thread_id, limit: 1)
      assistant_message = messages['data'].first
      
      # Parse the response
      parse_checklist_assistant_response(assistant_message, original_checklist_items)
      
    when 'requires_action'
      # Handle function calling
      required_action = run_data['required_action']
      if required_action && required_action['type'] == 'submit_tool_outputs'
        tool_calls = required_action['submit_tool_outputs']['tool_calls']
        
        Rails.logger.info "Processing #{tool_calls.length} tool calls"
        
        # Process function calls
        tool_outputs = []
        tool_calls.each do |tool_call|
          if tool_call['function']['name'] == 'return_checklist_results'
            # Parse the function arguments
            function_args = JSON.parse(tool_call['function']['arguments'])
            Rails.logger.info "Function called with #{function_args['results']&.length || 0} results"
            
            # Return the results directly
            return function_args['results'] || []
          end
        end
        
        # If we get here, no valid function call was found
        Rails.logger.error "No valid function calls found"
        raise "No valid checklist results returned"
      else
        Rails.logger.error "Unexpected required action type: #{required_action&.dig('type')}"
        raise "Unexpected OpenAI response format"
      end
      
    else
      Rails.logger.error "Unexpected run status: #{run_data['status']}"
      raise "Checklist analysis failed with status: #{run_data['status']}"
    end
  end
  
  # Parse assistant response for checklist (fallback method)
  def parse_checklist_assistant_response(assistant_message, original_checklist_items = [])
    Rails.logger.info "=== Parsing Checklist Assistant Response (Fallback) ==="
    
    content = assistant_message['content'].first
    
    if content['type'] == 'text'
      text_content = content['text']['value']
      Rails.logger.info "Raw response length: #{text_content.length} characters"
      Rails.logger.info "Raw response preview: #{text_content[0..200]}..."
      
      # Try to parse as JSON first
      begin
        parsed = JSON.parse(text_content)
        Rails.logger.info "Successfully parsed JSON response"
        Rails.logger.info "JSON keys: #{parsed.keys}"
        
        # Check for different possible response formats
        if parsed['results'] && parsed['results'].is_a?(Array)
          Rails.logger.info "Found 'results' array with #{parsed['results'].length} items"
          return parsed['results']
        elsif parsed['checklist_results'] && parsed['checklist_results'].is_a?(Array)
          Rails.logger.info "Found 'checklist_results' array with #{parsed['checklist_results'].length} items"
          return parsed['checklist_results']
        elsif parsed.is_a?(Array)
          Rails.logger.info "Response is direct array with #{parsed.length} items"
          return parsed
        else
          # Try to extract checklist items from the response structure
          Rails.logger.info "Attempting to extract checklist items from response structure"
          return extract_checklist_from_response(parsed)
        end
      rescue JSON::ParserError => e
        Rails.logger.error "JSON parsing failed: #{e.message}"
        Rails.logger.info "Response is not valid JSON, attempting text parsing"
        return parse_checklist_from_text(text_content)
      end
    else
      Rails.logger.error "Unexpected content type: #{content['type']}"
      return [{
        item: "Format Error",
        status: "Not Found",
        remarks: "Unexpected response format from analysis service.",
      }]
    end
  end

  # Helper method to extract checklist from response structure
  def extract_checklist_from_response(parsed_response)
    Rails.logger.info "=== Extracting Checklist from Response Structure ==="
    
    # Look for common patterns in the response
    checklist_items = []
    
    # Pattern 1: Look for individual checklist items in the response
    parsed_response.each do |key, value|
      if key.to_s.downcase.include?('checklist') && value.is_a?(Array)
        Rails.logger.info "Found checklist array in key: #{key}"
        return value
      end
    end
    
    # Pattern 2: Look for items that might be checklist results
    if parsed_response.is_a?(Hash)
      parsed_response.each do |key, value|
        if value.is_a?(Array) && value.any? { |item| item.is_a?(Hash) && item.key?('item') }
          Rails.logger.info "Found potential checklist items in key: #{key}"
          return value
        end
      end
    end
    
    # Pattern 3: Try to construct checklist from the response content
    if parsed_response['answer'] && parsed_response['answer'].is_a?(String)
      Rails.logger.info "Attempting to parse checklist from answer text"
      return parse_checklist_from_text(parsed_response['answer'])
    end
    
    # Pattern 4: Check if this is a regular assistant response that needs to be converted
    if parsed_response['answer'] || parsed_response['citations'] || parsed_response['needs_consent']
      Rails.logger.info "Detected regular assistant response format, converting to checklist"
      return convert_assistant_response_to_checklist(parsed_response, original_checklist_items)
    end
    
    Rails.logger.error "Could not extract checklist from response structure"
    return [{
      'item' => 'Analysis Error',
      'status' => 'Not Found',
      'remarks' => 'Could not extract checklist items from response structure.',
    }]
  end

  # Helper method to convert regular assistant response to checklist format
  def convert_assistant_response_to_checklist(assistant_response, original_checklist_items = [])
    Rails.logger.info "=== Converting Assistant Response to Individual Checklist Items ==="
    
    # Extract the answer text
    answer_text = assistant_response['answer'] || ''
    citations = assistant_response['citations'] || []
    needs_consent = assistant_response['needs_consent'] || false
    
    # If we have the original checklist items, create individual responses for each
    if original_checklist_items && original_checklist_items.any?
      Rails.logger.info "Creating individual responses for #{original_checklist_items.length} checklist items"
      
      return original_checklist_items.map do |item|
        # Try to find information about this specific item in the response
        item_info = extract_item_info_from_text(answer_text, item)
        
        if item_info[:found]
          {
            'item' => item,
            'status' => 'Yes',
            'remarks' => item_info[:details],
          }
        else
          {
            'item' => item,
            'status' => 'No',
            'remarks' => 'Not covered in the DPR',
            # 'documents' => []
          }
        end
      end
    end
    
    # Fallback: If the assistant couldn't find information, create a single summary
    if needs_consent || answer_text.empty? || answer_text.downcase.include?('not found')
      Rails.logger.info "Assistant response indicates no information found"
      return [{
        'item' => 'Analysis Summary',
        'status' => 'No',
        'remarks' => answer_text.present? ? answer_text : 'No relevant information found in the specified documents.',
        # 'documents' => citations
      }]
    end
    
    # Return the full response as a single item if no individual parsing is possible
    Rails.logger.info "Returning full response as single analysis item"
    return [{
      'item' => 'Full Analysis',
      'status' => 'Yes',
      'remarks' => answer_text.length > 1000 ? answer_text[0..500] + '...' : answer_text,
      # 'documents' => citations
    }]
  end
  
  # Helper method to extract information about a specific checklist item from text
  def extract_item_info_from_text(text, item_name)
    # Look for the item name or related keywords in the text
    item_keywords = item_name.downcase.split(/\s+/)
    text_lower = text.downcase
    
    # Check if any keywords from the item are mentioned in the text
    found_keywords = item_keywords.select { |keyword| text_lower.include?(keyword) }
    
    if found_keywords.any?
      # Try to extract the relevant section
      sentences = text.split(/[.!?]+/)
      relevant_sentences = sentences.select do |sentence|
        sentence_lower = sentence.downcase
        found_keywords.any? { |keyword| sentence_lower.include?(keyword) }
      end
      
      if relevant_sentences.any?
        return {
          found: true,
          details: relevant_sentences.join('. ').strip + '.'
        }
      end
    end
    
    # If no specific information found
    return {
      found: false,
      details: 'Not covered in the DPR'
    }
  end

  # Helper method to parse checklist from text content
  def parse_checklist_from_text(text_content)
    Rails.logger.info "=== Parsing Checklist from Text Content ==="
    
    # This is a fallback method to extract checklist items from text
    # We'll try to identify patterns that indicate checklist items
    
    checklist_items = []
    
    # Look for numbered or bulleted lists
    lines = text_content.split("\n")
    current_item = nil
    
    lines.each do |line|
      line = line.strip
      next if line.empty?
      
      # Look for patterns like "1. Item Name" or "- Item Name"
      if line.match(/^\d+\.\s*(.+)/) || line.match(/^[-*]\s*(.+)/)
        if current_item
          checklist_items << current_item
        end
        
        item_text = $1.strip
        current_item = {
          'item' => item_text,
          'status' => 'Unknown',
          'remarks' => 'Parsed from text response',
          # 'documents' => []
        }
      elsif current_item && line.match(/status[:\s]+(.+)/i)
        current_item['status'] = $1.strip
      elsif current_item && line.match(/remarks?[:\s]+(.+)/i)
        current_item['remarks'] = $1.strip
      end
    end
    
    # Add the last item if it exists
    if current_item
      checklist_items << current_item
    end
    
    if checklist_items.any?
      Rails.logger.info "Successfully parsed #{checklist_items.length} checklist items from text"
      return checklist_items
    end
    
    # If no structured items found, create a single item with the full text
    Rails.logger.info "No structured checklist found, creating single item with full text"
    return [{
      'item' => 'Full Analysis',
      'status' => 'Completed',
      'remarks' => text_content.length > 500 ? text_content[0..500] + '...' : text_content,
      # 'documents' => []
    }]
  end

  private
end