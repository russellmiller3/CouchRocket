require 'sinatra'
require 'sinatra/partial'
require 'better_errors'
require 'stripe'
require 'json'
require 'pry'
require 'rest_client'
require 'mailgun'

require_relative 'config/dotenv'
require_relative 'models'



#Stripe Setup
set :stripe_public_key, ENV['STRIPE_PUBLIC_KEY']
set :stripe_secret_key, ENV['STRIPE_SECRET_KEY']
Stripe.api_key = settings.stripe_secret_key

#MailGun Setup
set :mailgun_public_key, ENV['MAILGUN_PUBLIC_KEY']
set :mailgun_secret_key, ENV['MAILGUN_SECRET_KEY']
set :domain, ENV['DOMAIN']
mg_client = Mailgun::Client.new(settings.mailgun_secret_key)

set :partial_template_engine, :erb

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

helpers do
	def current_user
   @current_user ||= User.last
  end

  def To_Cents(dollar_amount)
  	dollar_amount * 100
  end

  def To_Dollars(cents)
  	cents/100
  end
end

def show_params
	p params
end

get "/" do
	if current_user.seller_profile
		@items = current_user.seller_profile.items
	else
		@items = nil
	end

	erb :'Home', :locals => { :items => @items, :user => current_user }
end


get "/admin" do
	@orders = Order.all
	erb :'Admin', :locals => {:orders => @orders}
end

get "/BuyerOrderConfirmation" do
	erb(:'BuyerOrderConfirmation')
end

get "/items" do
	@item = Item.new
	erb :'AddItem', :locals => { :item => @item, :user => current_user }
end

get "/items/:id" do
	show_params
	item_id = params[:id]
	@item = Item.get(item_id)
	show_params
	erb :'SalesPage', :locals => { :item => @item }
end

post "/items" do
	show_params

	if current_user.seller_profile
		@seller_profile = current_user.seller_profile
	else
		@seller_profile = SellerProfile.new({:user_id => current_user[:id]})
		@seller_profile.save
	end

	@seller_profile.errors.each do |error|
		puts error
	end

	item_attrs = params[:item]
	item_attrs.merge!({ :seller_profile_id => @seller_profile.id})
	@item = Item.new(item_attrs)
	To_Cents(@item.original_price)
	To_Cents(@item.asking_price)
	@item.save
	@item.errors.each do |error|
		puts error
	end

	#Send Seller Listing Confirmation Email
	seller_listing_confirmation = {
		:from => "CouchRocket <info@#{settings.domain}>",
		:to => "#{current_user.email}",
		:subject => "Thanks for Listing with CouchRocket",
		:html => erb(:'Emails/SellerListingConfirmation',:locals => { :current_user => current_user, :item => @item })
	}
	mg_client.send_message(settings.domain,seller_listing_confirmation)


  redirect "/"
end

post "/orders" do
	show_params

	#Create new user (buyer)
	user_attrs = params[:user]
	@new_user = User.new(user_attrs)
	@new_user.buyer_profile = BuyerProfile.new
	@new_user.save
	@new_user.buyer_profile.save
	@new_user.errors.each do |error|
			puts error
	end

	#Fetch Item from db
	item_id = params[:item][:id]
	@item = Item.get(item_id)

	#Create new order
	order_attrs = params[:order]
	@order = Order.new(order_attrs)
	@order.total_price = @item.asking_price + 30
	@order.shipping_address = @new_user.address
	@order.buyer_profile_id =	@new_user.buyer_profile.id
	#@order.stripe_token = params[:stripeToken]
	@order.save
	@order.errors.each do |error|
			puts error
	end

	#Attach item to order, save item
	@item.order_id = @order.id
	@item.save

	@item.errors.each do |error|
			puts error
	end

	# **Stripe Payment:**
	@amount = @item.asking_price

	# Get the credit card details submitted by the form
	token = params[:stripeToken]

	# Create a Customer
	customer = Stripe::Customer.create(
	:card => token,
	:email => @new_user.email,
	:metadata => {
		'Name' => @new_user.name,
		'Phone' => @new_user.phone,
		'Address' => @new_user.address
		}
	)

	@new_user.buyer_profile.stripe_customer_id = customer.id
	@new_user.buyer_profile.save


	#Send Buyer Confirmation Email
	buyer_confirmation = {
		:from => "CouchRocket <me@#{settings.domain}>",
	  :to => "#{@new_user.email}",
	  :subject => "Your #{@item.type} is Scheduled for Delivery",
	  :html => erb(:'Emails/BuyerConfirmation',
	  	:locals => {:new_user => @new_user,:item => @item,:order=>@order})
	}
	mg_client.send_message(settings.domain,buyer_confirmation)


	#Look up Seller
	@seller = @item.seller_profile.user

	#Send Seller Notification Email
	seller_pickup_notification ={
		:from => "CouchRocket <me@#{settings.domain}>",
		:to => "#{@seller.email}",
		:subject => "Time Sensitive: Your #{@item.type.downcase} has been sold!",
		:html => erb(:'Emails/SellerPickupNotification',
		:locals => {:seller => @seller,:item=>@item,:order=>@order})
	}
	mg_client.send_message(settings.domain,seller_pickup_notification)

	redirect "/BuyerOrderConfirmation"

end

post "/charge" do
	# show_params
	order_id = params[:order][:id]
	@order = Order.get(order_id)
	# p @order.total_price
	@buyer_profile = BuyerProfile.get(@order.buyer_profile_id)
	customer_id = @buyer_profile.stripe_customer_id
	# p customer_id

	charge_create = Stripe::Charge.create(
	    :amount => @order.total_price,
	    :currency => "usd",
	    :customer => customer_id
			)

  if charge_create.paid == true
		@order.charged = true
	else
		@order.charged = "Error"
	end

	@order.save

	p @order.charged

	redirect "/admin"

end






