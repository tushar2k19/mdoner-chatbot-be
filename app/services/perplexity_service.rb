class PerplexityService
  # This is the main class for handling Perplexity API calls
  
  # Class variables (shared across all instances)
  @@api_key = nil
  @@base_url = 'https://api.perplexity.ai/chat/completions'
  
  # Initialize method - runs when we create a new instance
  def initialize
    # Get API key from environment variables
    @@api_key = ENV['PERPLEXITY_API_KEY']
    
    # Check if API key exists
    if @@api_key.nil? || @@api_key.empty?
      raise "PERPLEXITY_API_KEY environment variable is not set"
    end
  end
  
  # Main method to search the internet
  def search(query, conversation_id = nil)
    begin
      # Get conversation context if conversation_id is provided
      context_messages = get_conversation_context(conversation_id) if conversation_id
      
      # Build the enhanced query with context
      enhanced_query = build_contextual_query(query, context_messages)
      
      # Call the Perplexity API with enhanced query
      response = call_perplexity_api(enhanced_query)
      
      # Format the response for our app
      format_response(response)
      
    rescue => error
      handle_error(error)
    end
  end
  
  private

# New method to get conversation context
def get_conversation_context(conversation_id)
  # Only get the last few messages to avoid overwhelming the API
  # and to prevent citation accumulation
  Message.where(conversation_id: conversation_id)
         .order(created_at: :desc)
         .limit(3)  # Reduced from 5 to 3 to minimize context
         .reverse
end

# New method to build contextual query
def build_contextual_query(query, context_messages)
  return query if context_messages.blank?
  
  # Only include the most recent user message and assistant response
  # to avoid citation accumulation
  recent_messages = context_messages.last(2)
  
  context_text = recent_messages.map do |msg|
    if msg.role == 'user'
      "User: #{msg.content}"
    elsif msg.role == 'assistant'
      # For assistant messages, only include the answer, not citations
      content = JSON.parse(msg.content) rescue msg.content
      if content.is_a?(Hash) && content['answer']
        "Assistant: #{content['answer']}"
      else
        "Assistant: #{msg.content}"
      end
    end
  end.compact.join("\n")
  
  "Previous conversation context:\n#{context_text}\n\nCurrent query: #{query}"
end
  
  # Method to actually call the Perplexity API
  def call_perplexity_api(query)
    # This method sends the HTTP request to Perplexity
    
    # Prepare the request headers
    headers = {
      'Authorization' => "Bearer #{@@api_key}",
      'Content-Type' => 'application/json'
    }
    
    # Prepare the request body (what we're sending to Perplexity)
    body = {
      model: 'sonar-pro',  # Correct Perplexity model name
      messages: [
        {
          role: 'user',
          content: query
        }
      ],
      max_tokens: 1000,  # Maximum length of response
      temperature: 0.2   # How creative the response should be (0 = very focused)
    }
    
    # Send the HTTP request using HTTParty
    response = HTTParty.post(@@base_url, {
      headers: headers,
      body: body.to_json,
      timeout: 30  # Add timeout to prevent hanging
    })
    
    # Check if the request was successful
    if response.success?
      response
    else
      raise "Perplexity API error: #{response.code} - #{response.message} - #{response.body}"
    end
  end
  
  # Method to format the response from Perplexity
  def format_response(response)
    # This method converts Perplexity's response into our app's format
    
    # Parse the JSON response
    data = JSON.parse(response.body)
    
    # Extract the answer from the response
    answer = data.dig('choices', 0, 'message', 'content')
    
    # Extract citations (sources) from the response
    citations = extract_citations(data)
    
    # Log citation information for debugging
    Rails.logger.info "=== Perplexity Citation Debug ==="
    Rails.logger.info "Raw response keys: #{data.keys}"
    Rails.logger.info "Citations found: #{citations.length}"
    citations.each_with_index do |citation, index|
      Rails.logger.info "  Citation #{index + 1}: #{citation[:title]} - #{citation[:url]}"
    end
    Rails.logger.info "=== End Citation Debug ==="
    
    # Return formatted response
    {
      answer: answer,
      citations: citations,
      needs_consent: false,  # Web search doesn't need consent (user already gave it)
      source: 'web'
    }
  end
  
  # Method to extract citations from Perplexity response
  def extract_citations(data)
    # This method finds source URLs in the response
    
    citations = []
    
    # First, try to get citations from search_results (most reliable)
    if data['search_results'] && data['search_results'].is_a?(Array)
      data['search_results'].each do |result|
        next unless result['url'] # Skip if no URL
        
        # Create a meaningful title from the result
        title = result['title'] || extract_domain_from_url(result['url'])
        
        citations << {
          title: title,
          url: result['url'],
          snippet: result['snippet'] || ''
        }
      end
    end
    
    # If no search_results, try citations array
    if citations.empty? && data['citations'] && data['citations'].is_a?(Array)
      data['citations'].each do |citation|
        next unless citation.is_a?(String) && citation.start_with?('http')
        
        title = extract_domain_from_url(citation)
        
        citations << {
          title: title,
          url: citation,
          snippet: ''
        }
      end
    end
    
    # If still no citations, try to extract URLs from the answer text
    if citations.empty?
      answer = data.dig('choices', 0, 'message', 'content')
      if answer
        # Look for URLs in the answer text
        urls = answer.scan(/https?:\/\/[^\s\)]+/)
        urls.uniq.each do |url|
          # Clean up URL (remove trailing punctuation)
          clean_url = url.gsub(/[.,;:!?]+$/, '')
          
          title = extract_domain_from_url(clean_url)
          
          citations << {
            title: title,
            url: clean_url,
            snippet: ''
          }
        end
      end
    end
    
    # Limit to maximum 5 citations to avoid clutter
    citations.first(5)
  end
  
  # Helper method to extract domain name from URL for better titles
  def extract_domain_from_url(url)
    begin
      uri = URI.parse(url)
      domain = uri.host
      
      # Remove www. prefix if present
      domain = domain.sub(/^www\./, '') if domain
      
      # Capitalize first letter and return
      domain&.split('.')&.first&.capitalize || 'Web Source'
    rescue
      'Web Source'
    end
  end
  
  # Method to handle errors
  def handle_error(error)
    # This method handles any errors that occur
    
    Rails.logger.error "Perplexity API Error: #{error.message}"
    
    # Return a user-friendly error response
    {
      answer: "Sorry, I couldn't search the internet right now. Please try again later.",
      citations: [],
      needs_consent: false,
      source: 'web',
      error: true
    }
  end
end