require 'sinatra'
require 'sinatra/partial'
require 'better_errors'

require_relative 'config/dotenv'
require_relative 'models'

set :partial_template_engine, :erb

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

helpers do
  def current_user
    @current_user ||= User.last
  end
end

def show_params
	p params
end

get "/" do
	@items = current_user.items

	erb :'Home', :locals => { :items => @items, :user => current_user }

end

get "/items" do
	@item = Item.new
	erb :'partials/AddItem', :locals => { :item => @item, :user => current_user }
end

get "/items/:id" do
	show_params
	item_id = params[:id]
	@item = Item.get(item_id)
	show_params
	erb :'partials/SalesPage', :locals => { :item => @item, :user => current_user }
end



post "/items" do
	show_params

	item_attrs = params[:item]
	item_attrs.merge!({ :user => current_user})
	item = Item.new(item_attrs)
	item.save

  redirect "/"

end

