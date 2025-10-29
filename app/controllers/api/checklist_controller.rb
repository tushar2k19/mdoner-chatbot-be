class Api::ChecklistController < ApplicationController
  include ApiResponseFormatter
  
  before_action :authenticate_user!
  
  # Document-specific checklist items
  DOCUMENT_SPECIFIC_CHECKLISTS = {
    "nagaland_innovation_hub.pdf" => [
      "Approval of concept note from MDONER (Minutes of EMIC)",
      "Compliance with the comments (if any) of the concerned line Ministry/Department and conditions specified by EMIC (if any) at the time of selection of project",
      "Endorsement on DPR by SLEC and submission of project proposal to MDoNER (minutes of SLEC to be enclosed)",
      "Project snapshot along with the Mechanism of O&M (during after project completion)",
      "Project rationale and intended beneficiaries",
      "Socio-economic impact of the project",
      "Timeline for implementation and sustanability plan",
      "Cost estimates, clearly indicating the basis for unit costs and source of funding for the project",
      "locations with geo-coordinates and satellite images or photographs of project site",
      "Alignment with Gati Shakti master plan to demonstrate convergence",
      "Output-Outcome framework with KPIs for monitoring the project",
      "Certificates of the following:\na) availability of encumbrance-free land for the project\nb) certification that costs proposed is as per the latest applicable schedule of rates\nc) non-duplication certificate"
    ],
    "mizoram_development_of_helipads.pdf" => [
      "Approval of concept note from MDONER (Minutes of EMIC)",
      "Alignment of proposed project with the focus areas",
      "project snapshot along with the Mechanism of O&M (during after project completion)",
      "Project rationale and intended beneficiaries",
      "Socio-economic impact of the project",
      "Timeline for implementation and sustanability plan",
      "Cost estimates, clearly indicating the basis for unit costs and source of funding for the project",
      "locations with geo-coordinates and satellite images or photographs of project site",
      "Alignment with Gati Shakti master plan to demonstrate convergence",
      "Output-Outcome framework with KPIs for monitoring the project",
      "Certificates of the following:\na) availability of encumbrance-free land for the project\nb) certification that costs proposed is as per the latest applicable schedule of rates\nc) non-duplication certificate",
      
    ],
    "khankawn_rongura_road_project.pdf" => [
      "Approval of concept note from MDONER (Minutes of EMIC)",
      "Alignment of proposed project with the focus areas",
      "Cost estimates, clearly indicating the basis for unit costs along with source of funding",
      "Mechanism for O&M (during and after project life)",
      "Timeline for implementation and sustanability plan",
      "locations with geo-coordinates or satellite images or photographs of project site",
      "Alignment with Gati Shakti master plan to demonstrate convergence",
      "Endorsement on DPR by SLEC and submission of project proposal to MDoNER (minutes of SLEC to be enclosed)",
      "Output Outcome framework with KPIs for monitoring",
      "Project rationale and intended beneficiaries",
      "Socio-economic impact of the project",
      "Certificates of the following:\na) availability of encumbrance-free land for the project\nb) certification that costs proposed is as per the latest applicable schedule of rates\nc) non-duplication certificate",
    ],
    "assam_road_project.pdf" => [
      "Approval of concept note from MDONER (Minutes of EMIC)",
      "Project rationale and intended beneficiaries",
      "Socio-economic impact of the project",
      "Cost estimates, clearly indicating the basis for unit costs and source of funding for the project",
      "locations with geo-coordinates or satellite images or photographs of project site",
      "Alignment with scheme guidelines and focus areas",
      "Sustainability plan and environmental considerations",
      "Endorsement on DPR by SLEC and submission of project proposal to MDoNER (minutes of SLEC to be enclosed)",
      "Alignment with Gati Shakti master plan to demonstrate convergence",
      "Mechanism for O&M (during and after project life)",
      "Timeline for implementation",
      "Statuatory Clearances for the Forest and Environment",
      "Output Outcome framework with KPIs for monitoring", 
      "Certificates of the following:\na) availability of encumbrance-free land for the project\nb) certification that costs proposed is as per the latest applicable schedule of rates\nc) non-duplication certificate",
    ],
    "coffee_development_nagaland.pdf" => [
      "Project rationale and intended beneficiaries",
      "Socio-economic impact of the project",
      "Cost estimates, clearly indicating the basis for unit costs and source of funding for the project",
      "locations with geo-coordinates or satellite images or photographs of project site",
      "Alignment with scheme guidelines and focus areas",
      "Sustainability plan and environmental considerations",
      "Mechanism for O&M (during and after project life)",
      "Timeline for implementation and the plan",
      "Alignment with Gati Shakti master plan to demonstrate convergence",
      "Statuatory Clearances for the Forest and Environment",
      "Output Outcome framework with KPIs for monitoring",
      "Certificates of the following:\na) availability of encumbrance-free land for the project\nb) certification that costs proposed is as per the latest applicable schedule of rates\nc) non-duplication certificate"
    ]
  }.freeze

  # Default checklist items (fallback)
  DEFAULT_CHECKLIST_ITEMS = [
    "Project rationale and the intended beneficiaries",
    "Socio-economic benefits of the project",
    "Alignment with scheme guidelines and focus areas",
    "Output-Outcome framework with KPIs for monitoring",
    "SDG or other indices that the KPIs will impact and how",
    "Total Project Cost for the Project",
    "Convergence plan with other ongoing government interventions",
    "Prioritized list of projects, duly signed by the chief secretary",
    "Alignment with Gati Shakti Master Plan",
    "Sustainability plan and environmental considerations"
  ].freeze
  
  # GET /api/checklist/defaults
  # Returns document-specific checklist items or default items
  def defaults
    document_name = params[:document_name]
    
    if document_name.present?
      # Normalize document name for lookup
      normalized_doc_name = normalize_doc_name(document_name)
      
      # Get document-specific checklist items
      checklist_items = DOCUMENT_SPECIFIC_CHECKLISTS[normalized_doc_name] || DEFAULT_CHECKLIST_ITEMS
      
      render_success(
        {
          checklist_items: checklist_items,
          total_items: checklist_items.length,
          document_name: document_name,
          is_document_specific: DOCUMENT_SPECIFIC_CHECKLISTS.key?(normalized_doc_name)
        },
        message: "Checklist items retrieved successfully"
      )
    else
      # Return default items if no document specified
      render_success(
        {
          checklist_items: DEFAULT_CHECKLIST_ITEMS,
          total_items: DEFAULT_CHECKLIST_ITEMS.length,
          document_name: nil,
          is_document_specific: false
        },
        message: "Default checklist items retrieved successfully"
      )
    end
  end
  
  # POST /api/checklist/analyze
  # Processes checklist items against selected documents
  def analyze
    Rails.logger.info "=== Checklist Analysis Request Started ==="
    Rails.logger.info "User ID: #{current_user&.id}"
    Rails.logger.info "Request params: #{params.inspect}"
    
    begin
      # Validate request parameters
      validation_result = validate_analyze_params
      if validation_result[:error]
        Rails.logger.error "Validation failed: #{validation_result[:error]}"
        return render_error(validation_result[:error], :unprocessable_entity)
      end
      
      document_names = validation_result[:document_names]
      checklist_items = validation_result[:checklist_items]
      
      Rails.logger.info "Validated documents: #{document_names}"
      Rails.logger.info "Validated checklist items: #{checklist_items.length} items"
      
      # Process checklist with OpenAI
      Rails.logger.info "Starting OpenAI checklist analysis..."
      checklist_results = OpenaiService.new.analyze_checklist(
        document_names: document_names,
        checklist_items: checklist_items
      )
      
      Rails.logger.info "OpenAI analysis completed successfully"
      Rails.logger.info "Results count: #{checklist_results.length}"
      
      # Format response
      response_data = {
        checklist_results: checklist_results,
        analyzed_documents: document_names,
        total_items: checklist_items.length,
        analysis_timestamp: Time.current.iso8601
      }
      
      Rails.logger.info "=== Checklist Analysis Request Completed Successfully ==="
      render_success(
        response_data,
        message: "Checklist analysis completed successfully"
      )
      
    rescue => e
      Rails.logger.error "=== Checklist Analysis Request Failed ==="
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      
      error_message = case e.message
      when /timeout/i
        "Analysis timed out. Please try with fewer checklist items or documents."
      when /rate limit/i
        "API rate limit exceeded. Please try again in a few minutes."
      when /OpenAI/i
        "AI service error. Please try again later."
      else
        "An error occurred during analysis. Please try again."
      end
      
      render_error(error_message, :internal_server_error)
    end
  end
  
  private
  
  def validate_analyze_params
    # Validate document_names parameter
    document_names = params[:document_names]
    if document_names.blank? || !document_names.is_a?(Array)
      return { error: "document_names parameter is required and must be an array" }
    end
    
    if document_names.empty?
      return { error: "At least one document must be selected" }
    end
    
    # Validate document names (accept both space and underscore variants, case-insensitive)
    # Currently using 5 documents: Nagaland Innovation Hub, Mizoram Development of Helipads, Assam Road Project, Khankawn Rongura Road Project, and Coffee Development Nagaland
    valid_documents = [
      # "Meghalaya_skywalk.pdf", # COMMENTED OUT - not currently used
      # "Tripura_Zoological_Park.pdf", # COMMENTED OUT - not currently used
      # "Kohima_Football_Ground.pdf", # COMMENTED OUT - not currently used
      "Nagaland_Innovation_Hub.pdf",
      "Mizoram_Development_of_Helipads.pdf",
      "Assam_Road_Project.pdf",
      "Khankawn_Rongura_Road_Project.pdf",
      "Coffee_Development_Nagaland.pdf"
    ]

    valid_normalized = valid_documents.map { |n| normalize_doc_name(n) }.to_set
    invalid_docs = document_names.reject { |name| valid_normalized.include?(normalize_doc_name(name)) }
    if invalid_docs.any?
      return { error: "Invalid document names: #{invalid_docs.join(', ')}" }
    end
    
    # Validate checklist_items parameter
    checklist_items = params[:checklist_items]
    if checklist_items.blank?
      # Use default items if none provided
      checklist_items = DEFAULT_CHECKLIST_ITEMS
    elsif !checklist_items.is_a?(Array)
      return { error: "checklist_items parameter must be an array" }
    elsif checklist_items.empty?
      return { error: "At least one checklist item is required" }
    elsif checklist_items.length > 15
      return { error: "Maximum 15 checklist items allowed" }
    end
    
    # Validate individual checklist items
    checklist_items.each_with_index do |item, index|
      if item.blank? || !item.is_a?(String)
        return { error: "Checklist item #{index + 1} must be a non-empty string" }
      end
      if item.length > 500
        return { error: "Checklist item #{index + 1} is too long (maximum 200 characters)" }
      end
    end
    
    {
      document_names: document_names,
      checklist_items: checklist_items
    }
  end

  # Normalize a document name to a canonical form for validation
  def normalize_doc_name(name)
    str = name.to_s.strip
    # Ensure extension is present and unified
    str += '.pdf' unless str.downcase.end_with?('.pdf')
    str = str.gsub(/\s+/, '_')
    str.downcase
  end
end
