# frozen_string_literal: true

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

source 'https://rubygems.org'

gem 'redcarpet', '~> 3.3', '>= 3.3.3'

gem 'middleman', github: 'middleman/middleman'
gem 'middleman-autoprefixer', '~> 2.10'
gem 'middleman-blog', github: 'middleman/middleman-blog'
gem 'middleman-minify-html', github: 'middleman/middleman-minify-html'

# For feed.xml.builder
gem 'builder', '~> 3.0'

gem 'tzinfo-data', platforms: %i[mswin mingw jruby x64_mingw]

group :development do
  gem 'rubocop', '>= 1.31'
end
