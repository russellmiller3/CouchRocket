require 'sinatra'
require 'sinatra/partial'
require 'better_errors'
require 'stripe'
require 'json'
require 'pry'
require 'rest_client'
require 'mailgun'
require 'twilio-ruby'

require_relative 'config/dotenv'
require_relative 'models'

#Stripe Setup
set :stripe_public_key, ENV['STRIPE_PUBLIC_KEY']
set :stripe_secret_key, ENV['STRIPE_SECRET_KEY']
Stripe.api_key = settings.stripe_secret_key
stripe_public_key = settings.stripe_public_key

#Twilio Setup
set :twilio_account_sid, ENV['TWILIO_ACCOUNT_SID']
set :twilio_auth_token, ENV['TWILIO_AUTH_TOKEN']
set :twilio_number, ENV['TWILIO_NUMBER']
twilio_client = Twilio::REST::Client.new settings.twilio_account_sid, settings.twilio_auth_token
twilio_number = settings.twilio_number

#MailGun Setup
set :mailgun_public_key, ENV['MAILGUN_PUBLIC_KEY']
set :mailgun_secret_key, ENV['MAILGUN_SECRET_KEY']
set :mail_domain, ENV['MAIL_DOMAIN']
mg_client = Mailgun::Client.new(settings.mailgun_secret_key)

set :partial_template_engine, :erb

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

#Global Variables
delivery_fee = 3000
return_insurance = 700
set :domain, ENV['DOMAIN']

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

get "/AddItem" do
  @item = Item.new
  erb :'AddItem', :locals => { :item => @item, :user => current_user, :return_fee => return_fee }
end

get "/Admin" do
  @orders = Order.all
  erb :'Admin', :locals => {:orders => @orders}
end

get "/BuyerOrderConfirmation" do
  erb(:'BuyerOrderConfirmation')
end

post "/Charge" do
  show_params
  order_id = params[:order_id]
  @order = Order.get(order_id)
  @order.approved = :true
  @buyer_profile = BuyerProfile.get(@order.buyer_profile_id)
  customer_id = @buyer_profile.stripe_customer_id

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
  erb :'Thanks'
end


get "/items/:id" do
  show_params
  item_id = params[:id]
  @item = Item.get(item_id)
  show_params
  erb :'SalesPage', :locals => { :item => @item,
    :delivery_fee => delivery_fee,
    :return_insurance => return_insurance,
    :stripe_public_key =>  stripe_public_key
    }
end

post "/items" do
  show_params

  if current_user.seller_profile
    @seller_profile = current_user.seller_profile
  else
    @seller_profile = SellerProfile.new({:user_id => current_user[:id]})
  end
  @seller_profile.pickup_notes = params[:pickup_notes]
  @seller_profile.save
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
    :from => "CouchRocket <info@#{settings.mail_domain}>",
    :to => "#{current_user.email}",
    :subject => "Thanks for Listing with CouchRocket",
    :html => erb(:'Emails/SellerListingConfirmation',:locals => { :current_user => current_user, :item => @item })
  }
  mg_client.send_message(settings.mail_domain,seller_listing_confirmation)

  redirect "/"

end


get "/BuyerAccept/:order_id" do
order_id = params[:order_id]
@order = Order.get(order_id)
@item = @order.item
erb(:'BuyerAccept',:locals => {:order => @order,:item => @item})
end


post "/NotifyBuyer/:order_id" do
order_id = params[:order_id]
order = Order.get(order_id)

  begin
    message = twilio_client.account.messages.create({
      :from => "+1#{twilio_number}",
      :to => "+1#{order.buyer_phone}",
      :body => "Your delivery person from CouchRocket is here with your
      #{order.item.brand} #{order.item.type}!\n http://#{settings.domain}/BuyerAccept/#{order_id}",
      :media_url => "http://i.imgur.com/iWHg83s.png"
      })
  rescue Twilio::REST::RequestError => e
    puts e.message
    puts message.sid
  end
erb(:'NotifyBuyer')
end


post "/NotifySeller/:order_id" do
order_id = params[:order_id]
order = Order.get(order_id)

  begin
    message = twilio_client.account.messages.create({
      :from => "+1#{twilio_number}",
      :to => "+1#{order.seller_phone}",
      :body => "Your delivery person from CouchRocket is here to pick up
      your #{order.item.brand} #{order.item.type} and deliver to your buyer.",
      :media_url => "http://i.imgur.com/iWHg83s.png"
      })
  rescue Twilio::REST::RequestError => e
    puts e.message
    puts message.sid
  end
erb(:'NotifySeller')
end

post "/orders" do
  show_params

  #Create new user (buyer)
  user_attrs = params[:user]
  @user = User.new(user_attrs)
  @user.buyer_profile = BuyerProfile.new
  @user.save
  @user.buyer_profile.save
  @user.errors.each do |error|
      puts error
  end

  #Fetch Item from db
  item_id = params[:item][:id]
  @item = Item.get(item_id)

  #Create new order, populate
  order_attrs = params[:order]
  @order = Order.new(order_attrs)
  @order.total_price = @item.asking_price + delivery_fee + return_insurance

  @order.buyer_name =@user.name
  @order.buyer_address = @user.address
  @order.buyer_phone = @user.phone

  @order.seller_name = @item.seller_profile.user.name
  @order.seller_phone = @item.seller_profile.user.phone
  @order.seller_address = @item.seller_profile.user.address
  @order.pickup_notes = @item.seller_profile.pickup_notes

  @order.buyer_profile = @user.buyer_profile

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

  # **Stripe Customer Creation**
  # Get the credit card details submitted by the form
  token = params[:stripeToken]

  customer = Stripe::Customer.create(
  :card => token,
  :email => @user.email,
  :metadata => {
    'Name' => @user.name,
    'Phone' => @user.phone,
    'Address' => @user.address
    }
  )

  @user.buyer_profile.stripe_customer_id = customer.id
  @user.buyer_profile.save


  #Send Buyer Confirmation Email
  buyer_confirmation = {
    :from => "CouchRocket <me@#{settings.mail_domain}>",
    :to => "#{@user.email}",
    :subject => "Your #{@item.type} is Scheduled for Delivery",
    :html => erb(:'Emails/BuyerConfirmation',
      :locals => {:user => @user,:item => @item,:order=>@order})
  }
  mg_client.send_message(settings.mail_domain,buyer_confirmation)

  #Look up Seller
  @seller = @item.seller_profile.user

  #Send Seller Notification Email
  seller_pickup_notification ={
    :from => "CouchRocket <me@#{settings.mail_domain}>",
    :to => "#{@seller.email}",
    :subject => "Time Sensitive: Your #{@item.type.downcase} has been sold!",
    :html => erb(:'Emails/SellerPickupNotification',
    :locals => {:seller => @seller,:item=>@item,:order=>@order})
  }
  mg_client.send_message(settings.mail_domain,seller_pickup_notification)

  redirect "/BuyerOrderConfirmation"
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




get "/register" do
  erb(:'Register')
end

post "/register" do
  show_params
  user_attrs = params[:user]
  @new_user  = User.new(user_attrs)
  @new_user.save
  p @new_user

  redirect "/AddItem"
end

get "/Return" do
  @order = Order.get(params[:order_id])
  erb(:'Return',:locals =>{:order=>@order})
end


post "/Return" do
  show_params
  @order = Order.get(params[:order][:id])
  @order.approved = "Returned"
  @order.return_reason = params[:order][:return_reason]

  #Charge Buyer Shipping Only
  @buyer_profile = BuyerProfile.get(@order.buyer_profile_id)
  customer_id = @buyer_profile.stripe_customer_id

  shipping_cost = delivery_fee + return_insurance

  charge_create = Stripe::Charge.create(
      :amount => shipping_cost,
      :currency => "usd",
      :customer => customer_id
      )

  if charge_create.paid == true
    @order.charged = true
  else
    @order.charged = "Error"
  end
  @order.save

  #Notify Shipper to Return Item
  begin
    message = twilio_client.account.messages.create({
      :from => "+1#{twilio_number}",
      :to => "+1#{@order.shipper_phone}",
      :body => "Return #{@order.item.type} to #{@order.seller_name} at #{@order.seller_address}.\n
      Please call #{@order.seller_phone} to let them know. Thanks!",
      :media_url => "http://i.imgur.com/iWHg83s.png"
      })
  rescue Twilio::REST::RequestError => e
  puts e.message
  puts message.sid
  end

  redirect "/ReturnComplete"

end

get "/ReturnComplete" do
  erb(:'ReturnComplete')
end

get "/ScheduleDelivery" do
  show_params
  @order = Order.get(params[:order_id])
  erb(:'ScheduleDelivery',
    :locals => {:order => @order})
end

post "/ScheduleDelivery" do
  show_params
  order_attrs = params[:order]
  @order = Order.get(params[:order][:id])
  @order.update(order_attrs)

  binding.pry

  #Send Shipper Email
  shipper_email = {
    :from => "CouchRocket <me@#{settings.mail_domain}>",
    :to => "#{@order.shipper_email}",
    :subject => "#{@order.item.brand} #{@order.item.type} delivery #{@order.target_delivery_date.strftime('%A, %B %d')}",
    :html => erb(:'Emails/Shipper',
      :locals => {:order=>@order})
  }
  mg_client.send_message(settings.mail_domain,shipper_email)

  @order.shipper_email_sent = true
  @order.save
  redirect "/Admin"

end


get "/SellerPaymentDetails" do
  erb(:'SellerPaymentDetails',:locals => {:stripe_public_key => stripe_public_key,:return_fee => return_fee})
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

  #Add to User's seller profile
  current_user.seller_profile.stripe_recipient_id = seller_stripe_recipient_profile.id
  current_user.save


  redirect "/"

end













