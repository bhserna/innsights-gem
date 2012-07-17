require 'resque'
require_relative './../workers/run_report'

module Innsights
  class Config::Report
    include Helpers::Config

    dsl_attr :event_name,  :upon
    dsl_attr :action_name, :report
    dsl_attr :created_at,  :timestamp
    dsl_attr :report_user, :user
    dsl_attr :act_on_user, :is_user
    
    attr_accessor :klass

    def initialize(klass=nil)
      @created_at = :created_at
      @event_name = :create
      @report_user = :user
      @act_on_user = :false
      unless klass.nil?
        @klass = klass
        @action_name = klass.name
      end
    end

    def run(record)
      if Innsights.enabled
        action = Action.new(self, record).as_hash

        case Innsights.queue_system
        when :resque
          Resque.enqueue(RunReport, action)
        when :delayed_job
          Innsights.client.delay.report(action)
        else
          Innsights.client.report(action)
        end
      end
    end
  end
end