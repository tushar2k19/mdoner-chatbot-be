class DocumentMapper
  # This maps OpenAI file IDs to readable document names
  # You'll need to update these with the real file IDs from your team lead
  
  def self.file_id_to_document_name(file_id)
    # Temporary mapping - replace with real ones from your team lead
    mapping = {
      'file-abc123' => 'Mizoram_Development_of_Helipads.pdf'
      'file-mno345' => 'Nagaland_Innovation_Hub.pdf'
    }
    
    # Return the mapped name or a fallback
    mapping[file_id] || "Document_#{file_id[-6..-1]}.pdf"
  end
  
  # Get all available document names
  def self.available_documents
    [
      'Mizoram_Development_of_Helipads.pdf',
      'Nagaland_Innovation_Hub.pdf'
    ]
  end
end