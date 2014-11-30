require 'data_mapper'

DataMapper.setup(:default, ENV['DATABASE_URL'])

class User
	include DataMapper::Resource

	property :id, Serial
	property :name, String
	property :email, String
	property :phone, String
	property :address, Text

	has 1, :seller_profile, { :child_key => [:user_id] }
	has 1, :buyer_profile, { :child_key => [:user_id] }

end

class SellerProfile
	include DataMapper::Resource

	property :id, Serial
	belongs_to :user
	has n, :items, { :child_key => [:seller_profile_id] }
end
8

class BuyerProfile
	include DataMapper::Resource

	property :id, Serial
	belongs_to :user
	has n, :items, { :child_key => [:buyer_profile_id] }
end

class Item
	include DataMapper::Resource

	property :id, Serial
	property :type, Text
	property :brand, Text
	property :notes, Text
	property :original_price, Integer
	property :asking_price, Integer
	property :picture1_url, Text
	property :picture2_url, Text
	property :picture3_url, Text
	property :sold, Boolean, { :default => false }

	belongs_to :seller_profile
	belongs_to :buyer_profile, :required => false
	belongs_to :order_details, :required => false

end

class OrderDetails
	include DataMapper::Resource

	property :id, Serial
	property :created_at, Date
	property :price, Integer
	property :fulfilled, Boolean, { :default => false }
	property :shipdate, Date
	property :charged, Boolean, { :default => false }
	property :delivery_notes, Text
	property :stripe_token, String
	property :stripe_customer_id, String

	has n, :items,  { :child_key => [:order_details_id] }

end


DataMapper.finalize
DataMapper.auto_upgrade!


