Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get 'test_auth' => 'application#test_auth'
  mount ActionCable.server => '/cable'
  
  # Auth
  post '/signin', to: 'signin#create'
  delete '/signout', to: 'signin#destroy'
  
  # Minimal documents endpoint placeholder for health
  get '/api/health', to: proc { [200, { 'Content-Type' => 'application/json' }, [{ status: 'healthy' }.to_json]] }

end
