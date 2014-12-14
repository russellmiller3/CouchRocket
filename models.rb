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
	property :stripe_recipient_id, String
	property :pickup_notes, Text

	belongs_to :user
	has n, :items, { :child_key => [:seller_profile_id] }
end


class BuyerProfile
	include DataMapper::Resource

	property :id, Serial
	property :stripe_customer_id, String

	belongs_to :user
	has n, :orders, { :child_key => [:buyer_profile_id]}
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
	belongs_to :order, :required => false

end

class Order
	include DataMapper::Resource

	property :id, Serial
	property :created_at, Date
	property :total_price, Integer
	property :buyer_name, Text
	property :buyer_phone, Text
	property :buyer_address, Text

	property :seller_name, Text
	property :seller_phone, Text
	property :seller_address, Text

	property :shipper_name, Text
	property :shipper_phone, Text
	property :shipper_email, Text
	property :shipped, Boolean, { :default => false }
	property :shipped_date, Date
	property :shipper_email_sent, Boolean, { :default => false}

	property :approved, Text
	property :return_reason, Text
	property :charged, Text
	property :seller_paid, Boolean, { :default => false }
	property :pickup_notes, Text
	property :delivery_notes, Text
	property :target_delivery_date, Date
	property :target_delivery_time_start, Integer
	property :admin_notes, Text

	has 1, :item,  { :child_key => [:order_id] }
	belongs_to :buyer_profile

end


DataMapper.finalize
DataMapper.auto_upgrade!


