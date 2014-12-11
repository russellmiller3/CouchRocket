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
stripe_public_key = settings.stripe_public_key

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

#Global Variables
delivery_fee = 30
return_fee = 7

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


  def Stripe_Error_Handling(code)
    begin
      code
    rescue Stripe::CardError => e
      # Since it's a decline, Stripe::CardError will be caught
    rescue Stripe::InvalidRequestError => e
      # Invalid parameters were supplied to Stripe's API
    rescue Stripe::AuthenticationError => e
      # Authentication with Stripe's API failed
      # (maybe you changed API keys recently)
    rescue Stripe::APIConnectionError => e
      # Network communication with Stripe failed
    rescue Stripe::StripeError => e
      # Display a very generic error to the user, and maybe send
      # yourself an email
      body = e.json_body
      err  = body[:error]
      puts "Status is: #{e.http_status}"
      puts "Type is: #{err[:type]}"
      puts "Code is: #{err[:code]}"
      # param is '' in this case
      puts "Param is: #{err[:param]}"
      puts "Message is: #{err[:message]}"
    end
  end

end

def show_params
  p params
end

#Begin Routes

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

  if @seller_profile.stripe_recipient_id
    redirect "/"
  else
    redirect "/SellerPaymentDetails"
  end

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

  #Create new order, populate
  order_attrs = params[:order]
  @order = Order.new(order_attrs)
  @order.total_price = @item.asking_price + delivery_fee
  @order.buyer_address = @new_user.address
  @order.buyer_profile_id = @new_user.buyer_profile.id
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

get "/register" do
  erb(:'Register')
end

post "/register" do
  show_params
  user_attrs = params[:user]
  @new_user  = User.new(user_attrs)
  @new_user.save
  p @new_user

end


get "/SellerPaymentDetails" do
  erb(:'SellerPaymentDetails',:locals => {:stripe_public_key => stripe_public_key})
end


post "/SellerPaymentDetails" do
  show_params
  seller_attrs = params[:seller]
  token = params[:stripeToken]   # Get the credit card details submitted by the form

  seller_stripe_recipient_profile = Stripe::Recipient.create(
    :name => seller_attrs[:name],
    :type => "individual",
    :tax_id => seller_attrs[:ssn],
    :email => current_user.email,
    :metadata => {
    'Address' => current_user.address
    },
    :card => token
    )

  # Create a Customer for charging Seller a return fee, if needed
  seller_stripe_customer_profile = Stripe::Customer.create(
  :card => token,
  :email => current_user.email,
  :metadata => {
    'Name' => current_user.name,
    'Phone' => current_user.phone,
    'Address' => current_user.address
    }
  )

  #Add to User's seller profile
  current_user.seller_profile.stripe_recipient_id = seller_stripe_recipient_profile.id
  current_user.seller_profile.stripe_customer_id = seller_stripe_customer_profile.id
  current_user.save


  redirect "/"

end


post "/PaySeller" do

  order = Order.get(params[:order][:id])

  buyer_share = 0.8*(order.total_price-delivery_fee)
  buyer_share = buyer_share.to_i


  pay_seller_transfer = Stripe::Transfer.create(
  :amount => buyer_share,
  :currency => "usd",
  :recipient => "#{current_user.seller_profile.stripe_recipient_id}",
  :description => "Payment for CouchRocket sale"
  )

  order.seller_paid = true
  order.save

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






