if ENV['RACK_ENV'] != 'production'
  Bundler.require(:development)
  Dotenv.load('.env')
else
	Bundler.require(:production)
end
