require 'active_support/core_ext/string/inflections'
require 'rails_admin/generic_support'

module RailsAdmin
  class AbstractModel

    @model_names = []

    # Returns all models for a given Rails app
    def self.all
      if @model_names.empty?
        excluded_models = RailsAdmin::Config.excluded_models.map(&:to_s)
        excluded_models << ['History']

        # orig regexp -- found 'class' even if it's within a comment or a quote
        filenames = Dir.glob(Rails.application.paths.app.models.collect { |path| File.join(path, "**/*.rb") })
        class_names = []
        filenames.each do |filename|
          class_names += File.read(filename).scan(/class ([\w\d_\-:]+)/).flatten
        end
        possible_models = Module.constants | class_names
        #Rails.logger.info "possible_models: #{possible_models.inspect}"
        models = (possible_models - excluded_models).map { |name| lookup(name, false) }

        #Rails.logger.info "final models: #{models.compact.inspect}"
        @model_names = models.compact.map(&:to_s).sort
      end

      @model_names.map { |name| new(name.constantize) }
    end

    # Given a string +model_name+, finds the corresponding model class
    def self.lookup(model_name,raise_error=true)
      begin
        model = model_name.constantize
      rescue NameError
        #Rails.logger.info "#{model_name} wasn't a model"
        raise "RailsAdmin could not find model #{model_name}" if raise_error
        return nil
      end

      if model.is_a?(Class) && superclasses(model).include?(ActiveRecord::Base)
        #Rails.logger.info "#{model_name} is a model"
        model
      else
        #Rails.logger.info "#{model_name} is NOT a model"
        nil
      end
    end

    attr_accessor :model

    def initialize(model)
      model = self.class.lookup(model.to_s.camelize) unless model.is_a?(Class)
      @model = model
      self.extend(GenericSupport)
      ### TODO more ORMs support
      require 'rails_admin/adapters/active_record'
      self.extend(RailsAdmin::Adapters::ActiveRecord)
    end

    private

    def self.superclasses(klass)
      superclasses = []
      while klass
        superclasses << klass.superclass if klass && klass.superclass
        klass = klass.superclass
      end
      superclasses
    end
  end
end