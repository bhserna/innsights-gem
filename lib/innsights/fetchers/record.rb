module Innsights
  module Fetchers
    # Stores the record instance that holds the key values that will be sent to the service
    # the way to get these values from within the record is configured using the `watch` DSL
    #
    # @attr [Object] record the record from which the report's attributes will be fetched
    # @attr [Object] report the report with the configuration of how to reach the report's attributes
    # @attr [String, Symbol] name the fetched name value
    # @attr [Object] user the fetched user object
    # @attr [Object] group the fetched group object
    # @attr [Time] created_at the fetched timestamp value
    # @attr [Hash] metrics the prepared metrics hash
    class Record
      include Innsights::Helpers::Config

      attr_accessor :record, :report, :name, :user, :group, :metrics, :created_at, :condition, :aggregates

      # Fetches the information from the record with the configuration set in report
      # 
      # @param [Innsights::Config::Model, Innsights::Config::Controller] report that holds the configuration
      # @param [Object] record the record that holds the information
      def initialize(record, report)
        @record = record
        @report = report
        @name = attr_call(report.name)
        @user = attr_call(report.report_user)
        @group = attr_call(report.report_group)
        @created_at = attr_call(report.created_at_method)
        @metrics = fetch_hash(report.metrics)
        @aggregates = fetch_hash(report.aggregates)
      end

      # Prepared hash to create a new Report
      # contains: name, user, :group, created_at and metrics for the report
      # 
      # @return [Hash] with the attributes needed by the Report
      def options
        aggregates.merge user: user, group: group, created_at: created_at, measure: metrics
      end

      # Specifies if the report should be sent to the service
      # evaluates the reports condition method, block or primitive. True by default
      #
      # @return [Boolean] true when it should be run, false when it shouldn't
      def run?
        return true if report.condition.nil?
        return attr_call(report.condition)
      end

      private

      def fetch_hash(raw_hash)
        result = {}
        raw_hash.each do |key, value|
          value = attr_call(value)
          result[key] = value unless value.nil?
        end
        result
      end

      def attr_call(call)
        dsl_call(record, call)
      end
    end
  end
end
