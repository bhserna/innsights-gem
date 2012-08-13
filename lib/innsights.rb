require 'rails'
require 'rest_client'
require 'highline/import'
require "innsights/version"

module Innsights
  
  module Helpers
    autoload :Tasks,            'innsights/helpers/tasks'
    autoload :Config,           'innsights/helpers/config'
  end
  
  module Actions
    autoload :User,             'innsights/actions/user'
    autoload :Group,            'innsights/actions/group'
  end
  
  module Config
    autoload :Report,           'innsights/config/reports/report'
    autoload :ModelReport,      'innsights/config/reports/model_report'
    autoload :ControllerReport, 'innsights/config/reports/controller_report'
    autoload :GenericReport,    'innsights/config/reports/generic_report'
    autoload :User,             'innsights/config/user'
    autoload :Group,            'innsights/config/group'
    autoload :Options,            'innsights/config/option'
  end

  autoload :ErrorMessage,       'innsights/error_message.rb'
  
  autoload :Action,             'innsights/action'
  autoload :Metric,             'innsights/metric'
  autoload :Client,             'innsights/client'

  include Config::Options

  ## Configuration defaults
  mattr_accessor :user_call
  @@user_call = :user
  
  mattr_accessor :user_id
  @@user_id = :id
  
  mattr_accessor :user_display
  @@user_display = :to_s
  
  mattr_accessor :group_call
  @@group_call = nil
  
  mattr_accessor :group_id
  @@group_id = :id
  
  mattr_accessor :group_display
  @@group_display = :to_s
  
  mattr_accessor :reports
  @@reports = []
  
  mattr_accessor :enable_hash
  @@enable_hash = { development: true, test: true, staging:true, production:true }
  
  mattr_accessor :debugging
  @@debugging = false
  
  mattr_accessor :url
  @@url = "innsights.me"
  
  mattr_accessor :test_url
  @@test_url = "innsights.dev"

  mattr_accessor :client
  mattr_accessor :env_scope
  
  mattr_accessor :queue_system
  @@queue_system = nil
  @@supported_queue_systems = [:delayed_job, :resque]

  # Configured subdomain of the client app
  # @return [String] subdomain of current app
  def self.app_subdomain
    @@app_subdomain ||= credentials["app"]
  end
  
  # Configured token of client app
  # @return [String] authentication token of app
  def self.app_token
    @@app_token ||= credentials["token"]
  end

  # Configuration variables of client app
  # @return [Hash] containing the subdomain and authentication token of app
  def self.credentials(cred=nil)
    cred ||= credentials_from_yaml if rails?
    @@credentials ||= cred 
  end

  
  # Final url to post actions to, includes the rails app environment
  # @return [String] contains app subdomain, innsights url and client app environment
  def self.app_url
    "#{app_subdomain}." << @@url << "/#{self.env}"
  end
  
  # Sets testing environment on for local server development
  # @param [true,false] on testing on or off
  # @return [String] with local server url if on, nil if off
  mattr_reader :test_mode
  def self.test_mode=(on)
    @@test_mode = on
    @@url = @@test_url if on
  end
  
  # Main configuration method to create all event watchers
  # @yield Configuration for
  #   * App user class
  #   * Appp action reports
  def self.setup(&block)
    self.instance_eval(&block)
    self.client = Client.new(url, app_subdomain, app_token, self.env)
  end

  # Extra configuration for custom experience
  # @yield Configuration for
  #   * Queue system
  #   * Test mode
  def self.config(*envs, &block)
    self.instance_eval(&block) if envs.blank?
    envs.each do |env| 
      @@env_scope = env
      self.instance_eval(&block) if self.env == env.to_s
      @@env_scope = nil
    end
  end

  
  # Sets up the user class and configures the display and group
  # @yield Configuration for
  #   * display
  #   * id
  #   * group
  def self.user(klass, &block)
    self.user_call = klass.to_s.downcase.to_sym
    Config::User.class_eval(&block) if block_given? 
  end

  # Sets up an event observer for creating an action on Innsights
  # @yield Configuration for
  #   * Action Name
  #   * Timestamp
  #   * User call
  #   * Event Trigger
  def self.watch(klass, params={}, &block)
    report = Config::ModelReport.new(params[:class] || klass)
    report.instance_eval(&block)
    report.commit
  end

  # Sets up an event observer for creating an custom action on Innsights
  # @yield Configuration for
  #   * Action Name
  #   * Timestamp
  #   * User call
  #   * Event Trigger
  def self.on(catalyst, &block)
    report = Config::ControllerReport.new(catalyst)
    report.instance_eval(&block)
    report.commit
  end

  # Sets up the user class and configures the display and group
  # @param [:resque, :delayed_job]
  def self.queue(queue='')
    if @@supported_queue_systems.include?(queue)
      self.queue_system = queue 
    end
  end

  def self.test(test_mode='')
    self.test_mode = test_mode
  end
  
  # Creates and commit a GenericReport
  # @param [:name, :user]
  # @return [Innsights::Config::GenericReport]
  def self.report(name, options={})
    report = Innsights::Config::GenericReport.new(name, options)
    report.commit
    report
  end

  def self.enable(env=nil, param)
    env ||= @@env_scope
    if env.present?
      @@enable_hash[env.to_sym] = param 
    else
      @@enable_hash.each do |env, v|
        @@enable_hash[env.to_sym] = param
      end
    end
  end

  def self.enabled?
    @@enable_hash[self.env.to_sym] == true
  end

  if rails?
    require 'innsights/railtie'
  end
    
  private 

  def self.credentials_from_yaml
    YAML.load(File.open(File.join(Rails.root, 'config/innsights.yml')))["credentials"]
  end
end
