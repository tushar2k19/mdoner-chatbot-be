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
  def search(query)
    # This method will handle the entire search process
    # query: The user's question (e.g., "What are the project timelines?")
    
    begin
      # Call the Perplexity API
      response = call_perplexity_api(query)
      
      # Format the response for our app
      format_response(response)
      
    rescue => error
      # If something goes wrong, return an error response
      handle_error(error)
    end
  end
  
  private
  
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
    
    # Look for citations in the response
    if data['citations']
      data['citations'].each do |citation|
        citations << {
          title: 'Web Source',
          url: citation,
          snippet: ''
        }
      end
    end
    
    # Also check search_results for more detailed citations
    if data['search_results']
      data['search_results'].each do |result|
        citations << {
          title: result['title'] || 'Web Source',
          url: result['url'],
          snippet: result['snippet'] || ''
        }
      end
    end
    
    # If no citations found, try to extract URLs from the answer
    if citations.empty?
      answer = data.dig('choices', 0, 'message', 'content')
      if answer
        # Look for URLs in the answer text
        urls = answer.scan(/https?:\/\/[^\s]+/)
        urls.each do |url|
          citations << {
            title: 'Web Source',
            url: url,
            snippet: ''
          }
        end
      end
    end
    
    citations
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