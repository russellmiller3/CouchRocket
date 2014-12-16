require_relative './config/dotenv'

namespace :db do

	task :reset do
		Rake::Task["db:delete_database_file"].invoke
		Rake::Task["db:seed"].invoke
	end

	task :delete_database_file do
		if File.exist?("./development.db")
			File.delete("./development.db")
			puts "Old Database destroyed."
		else
			puts "Database already destroyed."
		end
	end

	task :seed do
	require_relative './models'

	#create User, Seller Profiles
		joe = User.create({
			:id=>"2",
			:name=>"Joe Seller",
			:email=>"russell@adamm.net",
			:phone=>"4158598060",
			:address=>"412 Hampshire Way, #4, San Francisco, CA 94023"
			})

		joe_sellerprofile = SellerProfile.create({
			:id=>"1",
			:user_id => "2",
			:pickup_notes => "Gate code is #234. Ask for Joe"
			})


	#create User, Buyer profile,

		tom = User.create({
			:id=>"1",
			:name=>"Tom Buyer",
			:email=>"ram@themillermediagroup.com",
			:phone=>"4158598060",
			:address=>"33 Regis Court, San Francisco, CA 97331"
			})

		tom_buyerprofile = BuyerProfile.create({
			:id=>"1",
			:user_id => "1",
			:stripe_customer_id => "cus_5FpdpefAHvug4r"

			})

	# Create 3 items

		item1 = Item.create({
				:id =>"1",
				:type=>"Couch",
				:brand=>"Davis",
				:notes=>"A fine leather couch suitable for all occasions",
				:original_price=>"10000",
				:asking_price=>"7000",
				:picture1_url=>"http://www.thisthatandlife.com/wp-content/uploads/2012/11/Craigslist-Man-Leather-Couch-225.jpg",
				:seller_profile_id=>"1",
				:order_id=>"1",
				:sold=>"true"

			})

		item2 = Item.create({
				:id =>"2",
				:type=>"Bed",
				:brand=>"Ikea",
				:notes=>"A very comfortable bed",
				:original_price=>"20000",
				:asking_price=>"12000",
				:picture1_url=>"http://jacobandlevis.com/CMS/uploads/Stafford_Queen_Bed.jpg",
				:seller_profile_id=>"1",
				:order_id=>"2"
			})

		item3 = Item.create({
				:id =>"3",
				:type=>"Chair",
				:brand=>"Nordstrom",
				:notes=>"Great looking chair",
				:original_price=>"8000",
				:asking_price=>"6000",
				:picture1_url=>"http://www.ikea.com/PIAimages/0122106_PE278491_S5.JPG",
				:seller_profile_id=>"1",
			})

# Create 2 orders

		order1 = Order.create({
				:id => "1",
				:item => Item.get(1),
				:buyer_profile_id => "1",
				:total_price => "7000",
				:shipped => "true",
				:shipped_date => "2014-12-07T20:05:42-08:00",
				:approved => "true",
				:buyer_address => "33 Regis Court, San Francisco, CA 97331",
				:target_delivery_date =>"2014-12-07",
				:target_delivery_time_start =>"6"
			})

		order2 = Order.create({
				:id => "2",
				:item => Item.get(2),
				:buyer_profile_id => "1",
				:total_price => "12000",
				:shipped => "true",
				:shipped_date => "2014-12-07T20:05:42-08:00",
				:approved => "true",
				:buyer_address => "33 Regis Court, San Francisco, CA 97331",
				:target_delivery_date =>"2014-12-07",
				:target_delivery_time_start =>"6"
			})


		joe.save
		joe_sellerprofile.save
		tom.save
		tom_buyerprofile.save

		item1.save
		item2.save
		item3.save

		order1.save
		order2.save

		puts "New Database seeded."
		end

end