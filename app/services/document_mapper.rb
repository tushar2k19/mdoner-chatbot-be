class DocumentMapper
  # This maps OpenAI file IDs to readable document names
  # You'll need to update these with the real file IDs from your team lead
  
  def self.file_id_to_document_name(file_id)
    # Temporary mapping - replace with real ones from your team lead
    mapping = {
      'file-abc123' => 'Manipur_DPR.pdf',
      'file-def456' => 'Meghalaya_skywalk.pdf', 
      'file-ghi789' => 'Tripura_Zoological_Park.pdf',
      'file-jkl012' => 'Kohima_Football_Ground.pdf',
      'file-mno345' => 'Nagaland_Innovation_Hub.pdf'
    }
    
    # Return the mapped name or a fallback
    mapping[file_id] || "Document_#{file_id[-6..-1]}.pdf"
  end
  
  # Get all available document names
  def self.available_documents
    [
      'Manipur_DPR.pdf',
      'Meghalaya_skywalk.pdf',
      'Tripura_Zoological_Park.pdf', 
      'Kohima_Football_Ground.pdf',
      'Nagaland_Innovation_Hub.pdf'
    ]
  end
end