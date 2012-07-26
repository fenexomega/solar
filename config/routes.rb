Solar::Application.routes.draw do 

  devise_for :users, :path_names => {:sign_up => :register}, :skip => [:sessions]

  devise_scope :user do
    get  :login, :to => "devise/sessions#new"
    post :login, :to => "devise/sessions#create"
    get  :logout, :to => "devise/sessions#destroy"
    get "/", :to => "devise/sessions#new"
    resources :sessions, :only => [:create]
  end

  ## curriculum_units/:id/participants
  ## curriculum_units/:id/informations
  resources :curriculum_units do
    get :list, :on => :collection
    member do
      get :participants
      get :informations
      get :home
    end
    resources :groups, :only => [:index]
  end

  ## curriculum_units/:id/groups
  # get 'curriculum_units/:curriculum_unit_id/groups' => "groups#list", :as => :groups_curriculum_unit

  ## groups/:id/discussions
  resources :groups, :except => [:show] do
    resources :discussions, :only => [:index]
    get :list, :on => :collection
  end

  ## discussions/:id/posts
  resources :discussions, :only => [] do
    resources :posts, :except => [:show, :new, :edit]
    controller :posts do
      get "posts/user/:user_id", :to => :show, :as => "posts_of_the_user"
      get "posts/:type/:date(/order/:order(/limit/:limit))", :to => :index, :defaults => {:display_mode => 'list'} # :types => [:news, :history]; :order => [:asc, :desc]
    end
  end

  ## posts/:id/post_files
  resources :posts, :only => [] do
    resources :post_files, :only => [:new, :create, :destroy, :download] do
      get :download, :on => :member
    end
  end

  ## users/:id/photo
  ## users/edit_photo
  resources :users do
    get :photo, :on => :member
    get :edit_photo, :on => :collection
  end

  ## allocations/enrollments
  resources :allocations, :except => [:new] do
    get :enrollments, :action => :index, :on => :collection
    member do
      delete :cancel, :action => :destroy
      delete :cancel_request, :action => :destroy, :defaults => {:type => 'request'}
    end
  end

  resources :enrollments, :only => [:index]
  resources :offers
  resources :scores, :only => [:show]
  resources :courses

  resources :group_assignments, :only => [:index] do
    post :manage_groups, :on => :collection
  end

  mount Ckeditor::Engine => "/ckeditor"

  get "pages/index"
  get "pages/team"
  get "access_control/index"
  get "schedules/show"
  get "portfolio/public_files_send"
  get "scores/:id/history_access" => "scores#history_access"
  get 'home' => "users#mysolar", :as => :home
  get 'user_root' => 'users#mysolar'
  post "portfolio_teacher/evaluate_student_assignment"

  get "/media/users/:id/photos/:style.:extension", :to => "users#photo"
  get "/media/portfolio/individual_area/:file.:extension", :to => "access_control#portfolio_individual_area"
  get "/media/portfolio/public_area/:file.:extension", :to => "access_control#portfolio_public_area"
  get "/media/lessons/:id/:file.:extension", :to => "access_control#lesson"
  get "/media/messages/:file.:extension", :to => "access_control#message"

  match ':controller(/:action(/:id(.:format)))'

  root :to => 'devise/sessions#new'

end
