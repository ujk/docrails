require 'active_support/core_ext/array/wrap'

module ActiveRecord
  module Associations
    # = Active Record Associations
    #
    # This is the root class of all association proxies ('+ Foo' signifies an included module Foo):
    #
    #   AssociationProxy
    #     BelongsToAssociation
    #     BelongsToPolymorphicAssociation
    #     AssociationCollection + HasAssociation
    #       HasAndBelongsToManyAssociation
    #       HasManyAssociation
    #         HasManyThroughAssociation + ThroughAssociation
    #     HasOneAssociation + HasAssociation
    #       HasOneThroughAssociation + ThroughAssociation
    #
    # Association proxies in Active Record are middlemen between the object that
    # holds the association, known as the <tt>@owner</tt>, and the actual associated
    # object, known as the <tt>@target</tt>. The kind of association any proxy is
    # about is available in <tt>@reflection</tt>. That's an instance of the class
    # ActiveRecord::Reflection::AssociationReflection.
    #
    # For example, given
    #
    #   class Blog < ActiveRecord::Base
    #     has_many :posts
    #   end
    #
    #   blog = Blog.find(:first)
    #
    # the association proxy in <tt>blog.posts</tt> has the object in +blog+ as
    # <tt>@owner</tt>, the collection of its posts as <tt>@target</tt>, and
    # the <tt>@reflection</tt> object represents a <tt>:has_many</tt> macro.
    #
    # This class has most of the basic instance methods removed, and delegates
    # unknown methods to <tt>@target</tt> via <tt>method_missing</tt>. As a
    # corner case, it even removes the +class+ method and that's why you get
    #
    #   blog.posts.class # => Array
    #
    # though the object behind <tt>blog.posts</tt> is not an Array, but an
    # ActiveRecord::Associations::HasManyAssociation.
    #
    # The <tt>@target</tt> object is not \loaded until needed. For example,
    #
    #   blog.posts.count
    #
    # is computed directly through SQL and does not trigger by itself the
    # instantiation of the actual post records.
    class AssociationProxy #:nodoc:
      alias_method :proxy_respond_to?, :respond_to?
      alias_method :proxy_extend, :extend
      delegate :to_param, :to => :proxy_target
      instance_methods.each { |m| undef_method m unless m.to_s =~ /^(?:nil\?|send|object_id|to_a)$|^__|^respond_to_missing|proxy_/ }

      def initialize(owner, reflection)
        @owner, @reflection = owner, reflection
        @updated = false
        reflection.check_validity!
        Array.wrap(reflection.options[:extend]).each { |ext| proxy_extend(ext) }
        reset
        construct_scope
      end

      # Returns the owner of the proxy.
      def proxy_owner
        @owner
      end

      # Returns the reflection object that represents the association handled
      # by the proxy.
      def proxy_reflection
        @reflection
      end

      # Returns the \target of the proxy, same as +target+.
      def proxy_target
        @target
      end

      # Does the proxy or its \target respond to +symbol+?
      def respond_to?(*args)
        proxy_respond_to?(*args) || (load_target && @target.respond_to?(*args))
      end

      # Forwards <tt>===</tt> explicitly to the \target because the instance method
      # removal above doesn't catch it. Loads the \target if needed.
      def ===(other)
        load_target
        other === @target
      end

      # Returns the name of the table of the related class:
      #
      #   post.comments.aliased_table_name # => "comments"
      #
      def aliased_table_name
        @reflection.klass.table_name
      end

      # Returns the SQL string that corresponds to the <tt>:conditions</tt>
      # option of the macro, if given, or +nil+ otherwise.
      def conditions
        @conditions ||= interpolate_sql(@reflection.sanitized_conditions) if @reflection.sanitized_conditions
      end
      alias :sql_conditions :conditions

      # Resets the \loaded flag to +false+ and sets the \target to +nil+.
      def reset
        @loaded = false
        @target = nil
      end

      # Reloads the \target and returns +self+ on success.
      def reload
        reset
        load_target
        self unless @target.nil?
      end

      # Has the \target been already \loaded?
      def loaded?
        @loaded
      end

      # Asserts the \target has been loaded setting the \loaded flag to +true+.
      def loaded
        @loaded = true
      end

      # The target is stale if the target no longer points to the record(s) that the
      # relevant foreign_key(s) refers to. If stale, the association accessor method
      # on the owner will reload the target. It's up to subclasses to implement this
      # method if relevant.
      #
      # Note that if the target has not been loaded, it is not considered stale.
      def stale_target?
        false
      end

      # Returns the target of this proxy, same as +proxy_target+.
      def target
        @target
      end

      # Sets the target of this proxy to <tt>\target</tt>, and the \loaded flag to +true+.
      def target=(target)
        @target = target
        loaded
      end

      # Forwards the call to the target. Loads the \target if needed.
      def inspect
        load_target
        @target.inspect
      end

      def send(method, *args)
        if proxy_respond_to?(method)
          super
        else
          load_target
          @target.send(method, *args)
        end
      end

      protected
        def interpolate_sql(sql, record = nil)
          @owner.send(:interpolate_sql, sql, record)
        end

        # Forwards the call to the reflection class.
        def sanitize_sql(sql, table_name = @reflection.klass.table_name)
          @reflection.klass.send(:sanitize_sql, sql, table_name)
        end

        # Merges into +options+ the ones coming from the reflection.
        def merge_options_from_reflection!(options)
          options.reverse_merge!(
            :group   => @reflection.options[:group],
            :having  => @reflection.options[:having],
            :limit   => @reflection.options[:limit],
            :offset  => @reflection.options[:offset],
            :joins   => @reflection.options[:joins],
            :include => @reflection.options[:include],
            :select  => @reflection.options[:select],
            :readonly  => @reflection.options[:readonly]
          )
        end

        # Forwards +with_scope+ to the reflection.
        def with_scope(*args, &block)
          @reflection.klass.send :with_scope, *args, &block
        end

        # Construct the scope used for find/create queries on the target
        def construct_scope
          @scope = {
            :find   => construct_find_scope,
            :create => construct_create_scope
          }
        end

        # Implemented by subclasses
        def construct_find_scope
          raise NotImplementedError
        end

        # Implemented by (some) subclasses
        def construct_create_scope
          {}
        end

        def aliased_table
          @reflection.klass.arel_table
        end

        # Set the inverse association, if possible
        def set_inverse_instance(record)
          if record && invertible_for?(record)
            record.send("set_#{inverse_reflection_for(record).name}_target", @owner)
          end
        end

      private
        # Forwards any missing method call to the \target.
        def method_missing(method, *args)
          if load_target
            unless @target.respond_to?(method)
              message = "undefined method `#{method.to_s}' for \"#{@target}\":#{@target.class.to_s}"
              raise NoMethodError, message
            end

            if block_given?
              @target.send(method, *args)  { |*block_args| yield(*block_args) }
            else
              @target.send(method, *args)
            end
          end
        end

        # Loads the \target if needed and returns it.
        #
        # This method is abstract in the sense that it relies on +find_target+,
        # which is expected to be provided by descendants.
        #
        # If the \target is already \loaded it is just returned. Thus, you can call
        # +load_target+ unconditionally to get the \target.
        #
        # ActiveRecord::RecordNotFound is rescued within the method, and it is
        # not reraised. The proxy is \reset and +nil+ is the return value.
        def load_target
          return nil unless defined?(@loaded)

          if !loaded? && (!@owner.new_record? || foreign_key_present)
            @target = find_target
          end

          @loaded = true
          @target
        rescue ActiveRecord::RecordNotFound
          reset
        end

        # Can be overwritten by associations that might have the foreign key
        # available for an association without having the object itself (and
        # still being a new record). Currently, only +belongs_to+ presents
        # this scenario (both vanilla and polymorphic).
        def foreign_key_present
          false
        end

        # Raises ActiveRecord::AssociationTypeMismatch unless +record+ is of
        # the kind of the class of the associated objects. Meant to be used as
        # a sanity check when you are about to assign an associated record.
        def raise_on_type_mismatch(record)
          unless record.is_a?(@reflection.klass) || record.is_a?(@reflection.class_name.constantize)
            message = "#{@reflection.class_name}(##{@reflection.klass.object_id}) expected, got #{record.class}(##{record.class.object_id})"
            raise ActiveRecord::AssociationTypeMismatch, message
          end
        end

        # Returns the ID of the owner, quoted if needed.
        def owner_quoted_id
          @owner.quoted_id
        end

        # Can be redefined by subclasses, notably polymorphic belongs_to
        # The record parameter is necessary to support polymorphic inverses as we must check for
        # the association in the specific class of the record.
        def inverse_reflection_for(record)
          @reflection.inverse_of
        end

        # Is this association invertible? Can be redefined by subclasses.
        def invertible_for?(record)
          inverse_reflection_for(record)
        end
    end
  end
end
