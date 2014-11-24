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

	belongs_to :user

end

DataMapper.finalize
DataMapper.auto_upgrade!