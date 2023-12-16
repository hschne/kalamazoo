require 'bundler'
require 'json'
RAILS_REQUIREMENT = '~> 7.1.1'.freeze

def apply_template!
  assert_minimum_rails_version
  add_dependencies
  post_dependencies
end

def add_dependencies
  # Infrastructure
  gem 'litestack'

  # Deployment
  gem 'kamal'

  gem 'rubocop'
  gem 'rubocop-rails'
end

def post_dependencies
  after_bundle do
    rails_command 'db:create'
    rails_command 'db:migrate'
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