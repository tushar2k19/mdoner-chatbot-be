class DocumentMapper
  # Centralized mapping between human-friendly document names and OpenAI file_ids.
  # IMPORTANT: Populate the ENV variables below with your real file IDs from the
  # OpenAI Assistants Files page. If an ID is missing, attachments will be skipped
  # and the assistant will search all files configured on the Assistant.

  CANONICAL_DISPLAY_NAMES = [
    # 'Meghalaya Skywalk.pdf',
    # 'Tripura Zoological Park.pdf',
    # 'Kohima Football Ground.pdf',
    'Nagaland Innovation Hub.pdf',
    'Mizoram Development of Helipads.pdf',
    'Assam Road Project.pdf',
    'Khankawn Rongura Road Project.pdf',
    'Coffee Development Nagaland.pdf'
  ].freeze

  # Build name -> file_id map from ENV so deployments don't require code edits
  NAME_TO_FILE_ID = {
    # 'meghalaya_skywalk.pdf' => ENV['OPENAI_FILE_ID_MEGHALAYA'],
    'nagaland_innovation_hub.pdf' => 'file-9WYEvRbNZC2BDRcBvD94sG', #'file-CTzwMEmmcBsidZjU4PdtgP',
    'mizoram_development_of_helipads.pdf' => 'file-2zox9ddsxAu8aHFpaPLdcz', #'file-9zpZMkoWhkd7Ua6of8Ss4K',
    'assam_road_project.pdf' => 'file-UHsBDvmRKbojdEED8dzyPy', #'file-HWZQBZpqFoYiKWMhxKtDJh',
    'khankawn_rongura_road_project.pdf' => 'file-DcV8nEaEJgdwW3Cut7WezM',#'file-RR8o9DK99jgubhoU1au4Yu',
    'coffee_development_nagaland.pdf' => 'file-VyZ3evk98qT3QQMJkoBbM8' #'file-SsWbvBjh7BCVgVemFS2epi'
  }.freeze

  # Build file_id -> display name map
  FILE_ID_TO_NAME = NAME_TO_FILE_ID.each_with_object({}) do |(normalized_name, file_id), acc|
    next if file_id.nil? || file_id.strip.empty?

    display_name = case normalized_name
                  #  when 'meghalaya_skywalk.pdf' then 'Meghalaya Skywalk.pdf'
                  #  when 'tripura_zoological_park.pdf' then 'Tripura Zoological Park.pdf'
                  #  when 'kohima_football_ground.pdf' then 'Kohima Football Ground.pdf'
                   when 'nagaland_innovation_hub.pdf' then 'Nagaland Innovation Hub.pdf'
                   when 'mizoram_development_of_helipads.pdf' then 'Mizoram Development of Helipads.pdf'
                   when 'assam_road_project.pdf' then 'Assam Road Project.pdf'
                   when 'khankawn_rongura_road_project.pdf' then 'Khankawn Rongura Road Project.pdf'
                   when 'coffee_development_nagaland.pdf' then 'Coffee Development Nagaland.pdf'
                   else normalized_name.tr('_', ' ').split.map(&:capitalize).join(' ')
                   end

    acc[file_id] = display_name
  end.freeze

  def self.normalize(name)
    return '' if name.nil?
    str = name.to_s.strip.downcase
    str = str.end_with?('.pdf') ? str : (str + '.pdf')
    # Allow both spaces and underscores from different UIs
    str.tr(' ', '_')
  end

  # Map OpenAI file_id to human display filename
  def self.file_id_to_document_name(file_id)
    return nil if file_id.nil?
    FILE_ID_TO_NAME[file_id] || "Document_#{file_id.to_s[-6..-1]}.pdf"
  end

  # Map human-entered filename to OpenAI file_id (nil if unknown)
  def self.document_name_to_file_id(name)
    normalized = normalize(name)
    file_id = NAME_TO_FILE_ID[normalized]
    if file_id.nil? || file_id.strip.empty?
      Rails.logger.warn "No file_id configured for '#{name}' (normalized: #{normalized}). Set ENV OPENAI_FILE_ID_* to enable per-document restriction."
      return nil
    end
    file_id
  end

  # List available display names (used for validation and UI)
  def self.available_documents
    CANONICAL_DISPLAY_NAMES
  end
end