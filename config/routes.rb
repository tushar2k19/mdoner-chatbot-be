Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get 'test_auth' => 'application#test_auth'
  mount ActionCable.server => '/cable'
  
  # Auth
  post '/signin', to: 'signin#create'
  delete '/signout', to: 'signin#destroy'
  

  # External Search routes (ADD THIS SECTION)
  post 'external_search/search', to: 'external_search#search'
  post 'external_search/consent', to: 'external_search#consent'

  
  namespace :api do
      # Conversation routes (NEW - add this section)
      resources :conversations, only: [:create, :index, :show, :update, :destroy] do
        # Nested routes for messages (we'll implement this in Step 12)
        resources :messages, only: [:index, :create], controller: 'conversations/messages'
      end

    end

  # Minimal documents endpoint placeholder for health
  get '/api/health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'healthy' }.to_json]] }

end
