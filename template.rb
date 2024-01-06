# Inspired by Rails template
#
# See https://github.com/mattbrictson/rails-template
require 'bundler'
require 'json'
RAILS_REQUIREMENT = '~> 7.1.1'.freeze

def apply_template!
  assert_minimum_rails_version
  add_template_repository_to_source_path

  add_dependencies
  setup_templates
  post_dependencies
end

def username
  @username ||= 'hschne'
end

def hostname
  @hostname ||= "#{app_const_base.downcase}.com"
end

def add_dependencies
  # Infrastructure
  gem 'litestack'

  # Deployment
  gem 'kamal'

  # Utilities
  gem 'inline_svg'
  gem 'lograge'

  # Monitoring
  gem 'sentry-ruby'
  gem 'sentry-rails'

  gem_group :development do
    gem 'annotate'
    gem 'erb-formatter'

    gem 'rubocop-factory_bot'
    gem 'rubocop-rails-omakase', require: false
  end

  # Testing
  gem_group :development, :test do
    gem 'factory_bot_rails'
  end
end

def setup_templates
  template '.rubocop.yml'

  # Deployment
  template 'config/deploy.yml', force: true
  template 'github/deploy.yml', '.github/workflows/deploy.yml'

  # Config & Initializers
  template 'config/initializers/default_url_options.rb'
  copy_file 'config/initializers/lograge.rb'
  copy_file 'config/initializers/sentry.rb'

  append_to_file '.gitignore', <<~IGNORE
    # Ignore locally-installed gems.
    /vendor/bundle
  IGNORE
end

def post_dependencies
  after_bundle do
    # Set up Litestack
    generate('litestack:install')

    rails_command 'db:create'
    rails_command 'db:migrate'

    generate('annotate:install')

    # Initialize Kamal
    run 'kamal init'

    # Let's do an initial cleanup
    run 'bundle binstubs rubocop'
    run 'bin/rubocop -A'

    git :init
    git add: '.'
    git commit: %( -m 'Initial commit' )
  end
end

# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require 'tmpdir'
    source_paths.unshift(tempdir = Dir.mktmpdir('kalamazoo-'))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      '--quiet',
      'https://github.com/hschne/kalamazoo.git',
      tempdir
    ].map(&:shellescape).join(' ')

    if (branch = __FILE__[%r{kalamazoo/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. "\
           "You are using #{rails_version}. Continue anyway?"
  exit 1 if no?(prompt)
end

apply_template!
