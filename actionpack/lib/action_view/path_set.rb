module ActionView #:nodoc:
  # = Action View PathSet
  class PathSet < Array #:nodoc:
    %w(initialize << concat insert push unshift).each do |method|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{method}(*args)
          super
          typecast!
        end
      METHOD
    end

    def find(*args)
<<<<<<< HEAD
      find_all(*args).first || raise(MissingTemplate.new(self, *args))
=======
      find_all(*args).first || raise(MissingTemplate.new(self, "#{args[1]}/#{args[0]}", args[3], args[2]))
>>>>>>> 4c7da682b5580846867f1cce8dc63ca9b34c78cf
    end

    def find_all(path, prefixes = [], *args)
      prefixes.each do |prefix|
        each do |resolver|
          templates = resolver.find_all(path, prefix, *args)
          return templates unless templates.empty?
        end
      end
      []
    end

    def exists?(*args)
      find_all(*args).any?
    end

  protected

    def typecast!
      each_with_index do |path, i|
        path = path.to_s if path.is_a?(Pathname)
        next unless path.is_a?(String)
        self[i] = FileSystemResolver.new(path)
      end
    end
  end
end
