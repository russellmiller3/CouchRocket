require 'data_mapper'

DataMapper.setup(:default, ENV['DATABASE_URL'])

class User
	include DataMapper::Resource

	property :id, Serial
	property :name, String
	has n, :items

end


class Item
	include DataMapper::Resource

	property :id, Serial
	property :type, Text
	property :brand, Text
	property :notes, Text
	property :original_price, Float
	property :asking_price, Float
	property :lowest_price, Float
	property :picture1_url, Text
	property :picture2_url, Text
	property :picture3_url, Text
	property :sold, Boolean, :default  => false
	property :delivery_notes, Text

	belongs_to :user
	belongs_to :buyer

end

class Buyer
	include DataMapper::Resource

	property :id, Serial
	property :name, String
	property :email, String
	property :phone, String
	property :address, Text
	property :stripe_token, String
	property :stripe_customer_id, String

	has n, :items

end

DataMapper.finalize
DataMapper.auto_upgrade!

user = User.new(:id=>"1",:name=>"joe")
user.save
buyer = Buyer.new(:id=>"2",:name=>"dummy_buyer")
buyer.save
