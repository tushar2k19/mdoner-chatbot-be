class StreamingService
  # This class handles sending real-time updates to the frontend
  
  def initialize(response)
    # response = the HTTP response object from Rails
    # We'll use this to send data to the frontend
    @response = response
  end

  def send_event(event_type, data)
    # This method sends a single event to the frontend
    # event_type = what kind of event (like "status", "content", "complete")
    # data = the actual data to send
    
    # Format the event according to Server-Sent Events standard
    event_data = "event: #{event_type}\n" #what time of event
    event_data += "data: #{data.to_json}\n\n"
    
    # Send it to the frontend
    @response.stream.write(event_data)
    
    # Flush the buffer to ensure it's sent immediately
    @response.stream.flush if @response.stream.respond_to?(:flush)
  end

  def send_status_update(message)
    # Helper method to send status updates
    # message = human-readable status like "Searching documents..."
    send_event("status", { message: message })
  end

  def send_content_chunk(content)
    # Helper method to send content chunks
    # content = piece of the AI response
    send_event("content", { content: content })
  end

  def send_complete_response(full_response, citations = [])
    # Helper method to send the complete response
    # full_response = the complete AI response
    # citations = array of document references
    send_event("complete", { 
      response: full_response, 
      citations: citations 
    })
  end

  def send_error(error_message)
    # Helper method to send error messages
    # error_message = what went wrong
    send_event("error", { message: error_message })
  end
end